class TestLog < ActiveRecord::Base
  belongs_to :ent_module
  belongs_to :ent_test

  def self.getSumPoint(u_id,s_id,test_name)
    ent_test = EntTest.find(:first,:conditions=>"test_name = '#{test_name}'")
    if ent_test
      test_log = TestLog.find(:first,:conditions=>"user_id = '#{u_id}' and ent_seq_id = '#{s_id}' and ent_test_id = '#{ent_test[:id]}'",:order=>"id Desc")
      if test_log
        return test_log[:sum_point]
      else
        return 0
      end
    else
      return 0
    end
  end
end
