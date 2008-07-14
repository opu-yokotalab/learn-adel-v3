class EntTest < ActiveRecord::Base
  has_many :test_log
  has_many :question_log
end
