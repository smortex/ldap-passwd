require 'active_model'
require 'strong_password'

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
    @checker ||= StrongPassword::StrengthChecker.new(@password)
    @entropy ||= @checker.calculate_entropy(use_dictionary: true, extra_dictionary_words: File.readlines($config[:dictionary], encoding: 'utf-8').map { |x| x.chomp })
  end
end
