require 'geppetto/version'
require 'net/http'

# Mokey patch to suppress 'warning: peer certificate won't be verified in this SSL session'
class Net::HTTP
  alias_method :old_initialize, :initialize
  def initialize(*args)
    old_initialize(*args)
    @ssl_context = OpenSSL::SSL::SSLContext.new
    @ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
end
