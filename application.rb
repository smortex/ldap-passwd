require 'sinatra/base'
require 'haml'
require 'coffee_script'
require 'net/ldap'

class Application < Sinatra::Base
  configure do
    enable :logging
  end

  before do
    env['rack.logger'] = Logger.new(File.expand_path("../log/#{ENV['RACK_ENV'] || 'development'}.log", __FILE__))
  end

  get '/' do
    haml :index
  end

  post '/' do
    $logger ||= logger

    begin
      @current_password      = Secret.new(params[:current_password])
      @password              = Secret.new(params[:password])
      @password_confirmation = Secret.new(params[:password_confirmation])

      if @current_password.otp.nil?  || @password.otp.nil?  || @password_confirmation.otp.nil? then
        raise "Au moins un des mot de passe n'était pas suivi d'un OTP valide." 
      end

      if @current_password.public_id != @password.public_id || @password.public_id != @password_confirmation.public_id then
        raise 'Les OTP ne proviennent pas tous de la même YubiKey.'
      end

      if @password != @password_confirmation then
        raise 'Le nouveau mot de passe et sa confirmation ne concordent pas.'
      end

      if @password.entropy <= $config[:required_password_entropy] then
        raise "Le nouveau mot de passe n'a pas assez d'entropie (il a #{@password.entropy} bits d'entropie, alors qu'il en faut plus que #{$config[:required_password_entropy]})."
      end

      user_dn = "uid=#{params[:uid]},ou=people,dc=example,dc=com"
      ldap = Net::LDAP.new($config[:ldap].merge({
        :base => user_dn,
        :auth => {
            :method => :simple,
          :username => user_dn,
          :password => @current_password.password,
        }
      }))

      users = ldap.search(:scope => Net::LDAP::SearchScope_BaseObject)
      if users.nil? || users.count != 1 then
        raise "Échec d'authentification."
      end

      user = users.first

      if ! user.yubiKeyId.include?(@password.public_id) then
        raise "Veuillez utiliser votre YubiKey."
      end

      if ! ldap.replace_attribute(user_dn, :userPassword, Net::LDAP::Password.generate(:ssha, @password.password)) then
        raise "Erreur lors de la mise à jour de l'entrée de l'annuaire."
      end

      @notice = "Entropie du nouveau mot de passe : #{@password.entropy}."
      logger.info("New password set for #{user_dn} (entropy: #{@password.entropy})")

      begin
        if !$config[:skip_send_sms] then
          sms = Sms.new
          sms.message = "#{user.cn.first.force_encoding('UTF-8')} a changé de mot de passe (entropie : #{@current_password.entropy} -> #{@password.entropy})."
          sms.deliver
        end
      rescue Exception => e
        logger.error(e)
      end
    rescue Exception => e
      logger.error(e)
      @alert = e.message
    end
    haml :index
  end
end
