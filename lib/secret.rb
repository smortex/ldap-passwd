require 'active_model'
require 'strong_password'
require 'yubikey'

class Secret
  attr_reader :password, :otp, :public_id

  def initialize(password)
    @password  = password[0..-45]
    @otp       = password[-44..-1]
    @public_id = otp[0...12]

    if ! $config[:skip_check_otp] then
      if ! Yubikey::OTP::Verify.new(api_id: $config[:yubico_api_id], api_key: $config[:yubico_api_key], otp: @otp).valid? then
        raise 'invalid OTP'
      end
    end
  rescue Exception => e
    $logger.error(e)
    @password  = nil
    @otp       = nil
    @public_id = nil
  end

  def ==(other)
    !@password.nil? && @password == other.password
  end

  def entropy
    @checker ||= StrongPassword::StrengthChecker.new(@password)
    @entropy ||= @checker.calculate_entropy(use_dictionary: true, extra_dictionary_words: File.readlines($config[:dictionary]).map { |x| x.chomp })
  end
end
