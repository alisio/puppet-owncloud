require 'spec_helper'
describe 'alisiovps' do
  context 'with default values for all parameters' do
    it { should contain_class('alisiovps') }
  end
end
