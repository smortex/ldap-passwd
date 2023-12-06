# frozen_string_literal: true

require 'active_model'

class Secret
  attr_reader :password

  include Comparable

  def initialize(password)
    @password  = password
  end

  def <=>(other)
    @password <=> other.password
  end

  def entropy
    PasswordChecker.instance.calculate_entropy(@password)
  end
end
