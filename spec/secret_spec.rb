require 'spec_helper.rb'

require 'secret.rb'

require 'logger'

$logger = Logger.new(STDERR)
$logger.level = Logger::FATAL

$config = {
  skip_check_otp: true,
  dictionary: '/dev/null',
 }

describe Secret do
  it 'parses its components' do
    secret = Secret.new('passwordccccccdhuncrhthbnicejeedvrniienhffrvrdkfjdcn')
    expect(secret.password).to eq('password')
    expect(secret.otp).to eq('ccccccdhuncrhthbnicejeedvrniienhffrvrdkfjdcn')
    expect(secret.public_id).to eq('ccccccdhuncr')

    secret = Secret.new('Hello World')
    expect(secret.password).to be_nil
    expect(secret.otp).to be_nil
    expect(secret.public_id).to be_nil
  end

  it 'compares passwords' do
    s1 = Secret.new('helloccccccdhuncrkltbvlcdrlhdcdfhdutnuukdlfgbreln')
    s2 = Secret.new('helloccccccdhuncrdkulhkfdijviheeulrtneedbddfvkurr')
    s3 = Secret.new('worldccccccdhuncrtltfgkegbevtdfcrndkkkcdnujdjngnr')
    s4 = Secret.new('invalid')
    s5 = Secret.new(nil)

    expect(s1 == s2).to be_truthy
    expect(s1 == s3).to be_falsy
    expect(s4 == s5).to be_falsy
  end

  it 'computes passwords entropy' do
    s1 = Secret.new('passwordxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx')
    s2 = Secret.new(']XLJ>&(>*Oxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx')
    s3 = Secret.new('correct horse battery staplexxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx')
    expect(s1.entropy).to eq(2)
    expect(s2.entropy).to be > s1.entropy
    expect(s3.entropy).to be > s2.entropy
  end
end
