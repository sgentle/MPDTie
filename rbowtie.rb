#!/usr/bin/env ruby

require 'rubygems'
require 'net/http'
require 'cgi'
require 'plist'
require 'thread'
require 'dnssd'
require 'uuid'

Thread.abort_on_exception = true


class Bowtie
	attr_accessor :deviceID, :name, :player_position, :info

	class << self
		attr_accessor :bowties, :all

		Bowtie.bowties = {}
		
		@deviceID = nil
		@connect_cb = nil

		def connect_callback(&block)
			@connect_cb = block
		end

		def deviceID
			return @deviceID if @deviceID

			homedir = File.expand_path('~')
			bowfile = File.join(homedir, '.bowtie')
			if File.exists? bowfile
				@deviceID = File.read(bowfile).chomp
			else
				@deviceID = UUID.generate
				File.open(bowfile,'w') do |f|
					f.write(@deviceID)
				end
			end
			
			return @deviceID
		end

		def pair(deviceID = self.deviceID, name = "RBowtie on #{Socket.gethostname}")
			puts "deviceID: #{deviceID}"
			DNSSD::Service.new.register name, "_bttouch._tcp", nil, 56789, nil, DNSSD::TextRecord.new('deviceID'=>deviceID) do |r|
 				 puts "successfully registered: #{r.inspect}"
			end

		end

		def connect_all(deviceID = self.deviceID, name = "RBowtie on #{Socket.gethostname}")
			@dnssdthread = Thread.new do
				DNSSD::Service.new.browse '_bttremote._tcp' do |reply|
					DNSSD::Service.new.resolve(reply) do |resolve|
						key = resolve.text_record['deviceID']
						
						unless self.bowties[key]
							newtie = self.new(deviceID, name)
							
							@connect_cb.call(newtie) if @connect_cb
							
							#Could have a call to DNSSD::Service#getaddrinfo, but not sure if it's needed
							newtie.connect(resolve.target, resolve.port)
							
							self.bowties[key] = newtie
						end

						resolve.service.stop
					end
				end
			end	
		end

		all = Object.new
		def all.method_missing(method, *params, &block)
			Bowtie.each_bowtie do |bowtie|
				bowtie.method(method).call(*params, &block)
			end
		end

		Bowtie.all = all


		def each_bowtie
			self.bowties.each do |k, bowtie|
				yield bowtie
			end
		end
	end


	def initialize(deviceID, name="RBowtie on #{Socket.gethostname}")
		@deviceID = deviceID || Bowtie.deviceID 
		puts "DeviceID: #{@deviceID}"
		@name = name
		@httplock = Mutex.new

		@player_position = 0
		@info = {}
	end

	def makepostdata(hash)
		hash.collect{|a, b| "#{CGI.escape(a.to_s)}=#{CGI.escape(b.to_s)}"}.join("&")	
	end

	def check_for_commands
		return unless @connection
		
		@info_cb.call(self) if @info_cb

		respdata = nil
		@httplock.synchronize do	
			response = @connection.request_get('/pendingCommands?' + makepostdata({:deviceID => @deviceID, :playerPosition => @player_position}))
			respdata = Plist.parse_xml(response.body)
		end
		respdata.each do |cmd|
			puts "command: #{cmd}"
			@cmd_cb.call(self, cmd) if @cmd_cb
		end
	end

	def info_callback(&block)
		puts "registered info callback"
		@info_cb = block
	end

	def command_callback(&block)
		puts "registered command callback"
		@cmd_cb = block
	end

	def connect(ip, port=49159)
		@connection = Net::HTTP.start(ip, port)		
		respdata = nil
		@httplock.synchronize do	
			response = @connection.request_post('/connect', makepostdata({:deviceID => @deviceID, :deviceName => @name}))
			respdata = Plist.parse_xml(response.body)
		end
		raise "failed to connect: #{respdata['error']}" unless respdata['success']

		@max_update_interval = respdata['maxUpdateInterval']

		
		@info_cb.call(self) if @info_cb
		
		update_track()
	
		@cmdthread = Thread.new do
			loop do
				check_for_commands
				sleep @max_update_interval || 0.25
			end
		end	
	end

	def update_playstate(state)
		return unless @connection
		
		respdata = nil
		@httplock.synchronize do	
			response = @connection.request_post('/playbackStateChanged?'+makepostdata({:deviceID => @deviceID}), makepostdata({:state => state}))
			respdata = Plist.parse_xml(response.body)
		end	
	
		raise "failed to update playstate: #{respdata[error]}" unless respdata['success']
	end

	def update_track
		return unless @connection
		
		respdata = nil
		@httplock.synchronize do	
			response = @connection.request_post('/trackChanged?'+makepostdata({:deviceID => @deviceID}), @info.to_plist)
			respdata = Plist.parse_xml(response.body)
		end

		raise "failed to update track: #{respdata[error]}" unless respdata['success']
	end

	def disconnect
		return unless @connection
		
		@connection.finish()
	end

	def wait_on_commands
		@cmdthread.join	
	end
end

