# frozen_string_literal: true

require 'sinatra/base'
require 'haml'
require 'net/ldap'
require 'strong_password'
require 'singleton'

class PasswordChecker
  include Singleton

  def checker
    @checker ||= StrongPassword::StrengthChecker.new(use_dictionary: true, extra_dictionary_words: File.readlines($config[:dictionary], encoding: 'utf-8').map(&:chomp))
  end

  def calculate_entropy(password)
    checker.calculate_entropy(password)
  end
end

class PasswordChanger
  attr_reader :uid

  def initialize(uid:, current_password:, password:, password_confirmation:)
    @uid = uid

    @current_password      = Secret.new(current_password)
    @password              = Secret.new(password)
    @password_confirmation = Secret.new(password_confirmation)
  end

  def validate!
    raise(ApplicationException, 'Le nouveau mot de passe et sa confirmation ne concordent pas.') if @password != @password_confirmation
    raise(ApplicationException, "Le nouveau mot de passe n'a pas assez d'entropie (il a #{@password.entropy} bits d'entropie, alors qu'il en faut plus que #{$config[:required_password_entropy]}).") if @password.entropy <= $config[:required_password_entropy]
  end

  def change!
    validate!

    users = ldap.search(scope: Net::LDAP::SearchScope_BaseObject)
    raise(ApplicationException, "Votre nom d'utilisateur ou votre mot de passe actuel est erroné.") if users.nil? || users.count != 1

    raise(ApplicationException, "Erreur lors de la mise à jour de l'entrée de l'annuaire.") if !ldap.replace_attribute(user_dn, :userPassword, Net::LDAP::Password.generate(:ssha, @password.password))
  end

  def user_dn
    @user_dn ||= format($config[:user_dn], uid)
  end

  def ldap
    @ldap ||= Net::LDAP.new($config[:ldap].merge({
                                                   base: user_dn,
                                                   auth: {
                                                     method: :simple,
                                                     username: user_dn,
                                                     password: @current_password.password
                                                   }
                                                 }))
  end

  def entropy
    @password.entropy
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
    begin
      symbolized_params = params.to_h.transform_keys(&:to_sym)
      pc = PasswordChanger.new(symbolized_params)
      pc.change!

      @notice = "Entropie du nouveau mot de passe : #{pc.entropy}."
      logger.info("New password set for #{pc.user_dn} (entropy: #{pc.entropy})")
    rescue ApplicationException => e
      @alert = e.message
      logger.error(e.message)
    end
    haml :index
  end
end
