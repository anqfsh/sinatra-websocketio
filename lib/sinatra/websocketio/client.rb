require File.expand_path '../../sinatra-websocketio/version', File.dirname(__FILE__)
require 'websocket-client-simple'
require 'event_emitter'
require 'json'

module Sinatra
  module WebSocketIO
    class Client
      class Error < StandardError
      end

      include EventEmitter
      attr_reader :url, :session

      def initialize(url)
        @url = url
        @session = nil
        @websocket = nil
        @connecting = false
        @running = false

        on :__session_id do |session_id|
          @session = session_id
          emit :connect, @session
        end
      end

      def connect
        this = self
        @running = true
        url = @session ? "#{@url}/session=#{@session}" : @url
        begin
          @websocket = WebSocket::Client::Simple::Client.new url
        rescue StandardError, Timeout::Error => e
          connect
        end

        @websocket.on :message do |msg|
          begin
            data = JSON.parse msg.data
            this.emit data['type'], data['data']
          rescue => e
            this.emit :error, e
          end
        end

        @websocket.on :close do |e|
          if @connecting
            @connecting = false
            this.emit :disconnect, e
          end
          if @running
            Thread.new do
              sleep 10
              this.connect
            end
          end
        end

        @websocket.on :open do
          @connecting = true
        end

        return self
      end

      def close
        @running = false
        @websocket.close
      end

      def push(type, data)
        if @connecting
          emit :error, 'websocket not connecting'
          return
        end
        @websocket.send({:type => type, :data => data, :session => @session}.to_json)
      end

    end
  end
end
