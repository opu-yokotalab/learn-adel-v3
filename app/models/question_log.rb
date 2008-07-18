class QuestionLog < ActiveRecord::Base
  belongs_to :ent_test
  belongs_to :ent_question
end
