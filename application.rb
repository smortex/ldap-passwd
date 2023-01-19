require 'sinatra/base'
require 'haml'
require 'coffee_script'
require 'net/ldap'
require 'strong_password'
require 'singleton'

class PasswordChecker
  include Singleton

  def checker
    @checker ||= StrongPassword::StrengthChecker.new(use_dictionary: true, extra_dictionary_words: File.readlines($config[:dictionary], encoding: 'utf-8').map { |x| x.chomp })
  end

  def calculate_entropy(password)
    checker.calculate_entropy(password)
  end
end

class ApplicationException < StandardError
end

class Application < Sinatra::Base
  configure do
    enable :logging
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
        raise(ApplicationException, 'Le nouveau mot de passe et sa confirmation ne concordent pas.')
      end

      if @password.entropy <= $config[:required_password_entropy] then
        raise(ApplicationException, "Le nouveau mot de passe n'a pas assez d'entropie (il a #{@password.entropy} bits d'entropie, alors qu'il en faut plus que #{$config[:required_password_entropy]}).")
      end

      user_dn = format($config[:user_dn], params[:uid])
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
        raise(ApplicationException, "Votre nom d'utilisateur ou votre mot de passe actuel est erroné.")
      end

      user = users.first

      if ! ldap.replace_attribute(user_dn, :userPassword, Net::LDAP::Password.generate(:ssha, @password.password)) then
        raise(ApplicationException, "Erreur lors de la mise à jour de l'entrée de l'annuaire.")
      end

      @notice = "Entropie du nouveau mot de passe : #{@password.entropy}."
      logger.info("New password set for #{user_dn} (entropy: #{@password.entropy})")
    rescue ApplicationException => e
      @alert = e.message
    end
    haml :index
  end
end
