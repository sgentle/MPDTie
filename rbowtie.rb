#!/usr/bin/env ruby

require 'net/http'
require 'cgi'
require 'plist'

Thread.abort_on_exception = true


class Bowtie
	attr_accessor :deviceID, :name

	@player_position = 0

	def initialize(deviceID, name="RBowtie")
		@deviceID = deviceID
		@name = name
	end

	def makepostdata(hash)
		hash.collect{|a, b| "#{CGI.escape(a.to_s)}=#{CGI.escape(b.to_s)}"}.join("&")	
	end

	def check_for_commands
		return unless @connection
		
		@player_position = @pos_cb.call() if @pos_cb
	
		response = @connection.request_get('/pendingCommands?' + makepostdata({:deviceID => @deviceID, :playerPosition => @player_position}))
		respdata = Plist.parse_xml(response.body)

		respdata.each do |cmd|
			@cmd_cb.call(cmd) if @cmd_cb
		end
	end

	def position_callback(&block)
		@pos_cb = block
	end

	def command_callback(&block)
		@cmd_cb = block
	end

	def connect(ip, port=49159)
		@connection = Net::HTTP.start(ip, port)		
		response = @connection.request_post('/connect', makepostdata({:deviceID => @deviceID, :deviceName => @name}))
		respdata = Plist.parse_xml(response.body)

		raise "failed to connect: #{respdata[error]}" unless respdata['success']

		@max_update_interval = respdata['maxUpdateInterval']
		
		@cmdthread = Thread.new do
			loop do
				check_for_commands
				sleep @max_update_interval || 0.25
			end
		end	
	end

	def update_playstate(state)
		return unless @connection
		
		response = @connection.request_post('/playbackStateChanged?'+makepostdata({:deviceID => @deviceID}), makepostdata({:state => state}))
		respdata = Plist.parse_xml(response.body)
		
		raise "failed to update playstate: #{respdata[error]}" unless respdata['success']
	end

	def update_track()
		return unless @connection
		
		response = @connection.request_post('/trackChanged?'+makepostdata({:deviceID => @deviceID}),
			 {'playing' => false}.to_plist)
		respdata = Plist.parse_xml(response.body)
		
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


foo = Bowtie.new("f2170d25cdbae1e8eb242569f444a61596e954fd")
foo.connect("192.168.0.51")
