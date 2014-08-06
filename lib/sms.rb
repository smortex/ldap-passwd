require 'net/http'
require 'net/https'

class Sms
  attr_accessor :message

  def initialize(options = {})
    options.each do |k,v|
      instance_variable_set("@#{k}", v)
    end
  end

  def deliver
    uri = URI.parse('https://smsapi.free-mobile.fr/sendmsg')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    #http.ca_path = '/etc/ssl/certs'
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    req = Net::HTTP::Get.new(uri.path)
    req.set_form_data({
      'user' => $config[:sms_user].to_s,
      'pass' => $config[:sms_pass].to_s,
      'msg'  => @message,
    })
    req = Net::HTTP::Get.new(uri.path + '?' + req.body)
    res = http.request(req)
    return res.code == 200
  end
end
