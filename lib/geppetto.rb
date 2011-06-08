require 'geppetto/version'
require 'net/http'
require 'koala'
require 'logger'

# Monkey patch to suppress 'warning: peer certificate won't be verified in this SSL session'
class Net::HTTP
  alias_method :old_initialize, :initialize
  def initialize(*args)
    old_initialize(*args)
    @ssl_context = OpenSSL::SSL::SSLContext.new
    @ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
end


module Geppetto
  def self.log(msg)
    @@log ||=  Logger.new("geppetto.log", 'daily')
    # Filterout client secret
    match = msg.match(/.*client_secret=([a-z0-9]+)/)
    msg.sub!(match[1], '[filtered]') if match
    @@log.debug(msg)
  end

  # Define our own http service using Net::HTTP so we can log requests for debugging purpose
  module NetHTTPService
      # this service uses Net::HTTP to send requests to the graph
      def self.included(base)
        base.class_eval do
          require "net/http" unless defined?(Net::HTTP)
          require "net/https"
          require "net/http/post/multipart"

          include Koala::HTTPService

          def self.make_request(path, args, verb, options = {})
            # We translate args to a valid query string. If post is specified,
            # we send a POST request to the given path with the given arguments.

            # by default, we use SSL only for private requests
            # this makes public requests faster
            private_request = args["access_token"] || @always_use_ssl || options[:use_ssl]

            # if the verb isn't get or post, send it as a post argument
            args.merge!({:method => verb}) && verb = "post" if verb != "get" && verb != "post"

            http = create_http(server(options), private_request, options)
            http.use_ssl = true if private_request

            result = http.start do |http|
              response, body = if verb == "post"
                if params_require_multipart? args
                  Geppetto.log("curl -i -X #{verb.upcase} (multi-part-params) 'http#{http.use_ssl? ? 's':''}://#{http.address}:#{http.port}#{path}'")
                  http.request Net::HTTP::Post::Multipart.new path, encode_multipart_params(args)
                else
                  params = encode_params(args).split('&').collect {|param| "-d #{param} " }
                  Geppetto.log("curl -i -X #{verb.upcase} #{params.to_s} 'http#{http.use_ssl? ? 's':''}://#{http.address}:#{http.port}#{path}'")
                  http.post(path, encode_params(args))
                end
              else
                Geppetto.log("curl -i -X #{verb.upcase} 'http#{http.use_ssl? ? 's':''}://#{http.address}:#{http.port}#{path}?#{encode_params(args)}'")
                http.get("#{path}?#{encode_params(args)}")
              end
              Geppetto.log("#{response.code} #{body}") if response.code.to_i != 200
              Koala::Response.new(response.code.to_i, body, response)
            end
          end

          protected
          def self.encode_params(param_hash)
            # unfortunately, we can't use to_query because that's Rails, not Ruby
            # if no hash (e.g. no auth token) return empty string
            ((param_hash || {}).collect do |key_and_value|
              key_and_value[1] = key_and_value[1].to_json if key_and_value[1].class != String
              "#{key_and_value[0].to_s}=#{CGI.escape key_and_value[1]}"
            end).join("&")
          end
        
          def self.encode_multipart_params(param_hash)
            Hash[*param_hash.collect do |key, value| 
              [key, value.kind_of?(Koala::UploadableIO) ? value.to_upload_io : value]
            end.flatten]
          end

          def self.create_http(server, private_request, options)
            if options[:proxy]
              proxy = URI.parse(options[:proxy])
              http  = Net::HTTP.new(server, private_request ? 443 : nil,
                                    proxy.host, proxy.port, proxy.user, proxy.password)
            else
              http = Net::HTTP.new(server, private_request ? 443 : nil)
            end
            if options[:timeout]
              http.open_timeout = options[:timeout]
              http.read_timeout = options[:timeout]
            end
            http
          end
        end
      end
  end
end

Koala.http_service = Geppetto::NetHTTPService

