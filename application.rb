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
        raise "Votre nom d'utilisateur ou votre mot de passe actuel est erroné."
      end

      user = users.first

      if ! ldap.replace_attribute(user_dn, :userPassword, Net::LDAP::Password.generate(:ssha, @password.password)) then
        raise "Erreur lors de la mise à jour de l'entrée de l'annuaire."
      end

      @notice = "Entropie du nouveau mot de passe : #{@password.entropy}."
      logger.info("New password set for #{user_dn} (entropy: #{@password.entropy})")
    rescue Exception => e
      logger.error(e)
      @alert = e.message
    end
    haml :index
  end
end
