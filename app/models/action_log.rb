class ActionLog < ActiveRecord::Base
  belongs_to :ent_seq

  validates_inclusion_of :action_code, :in=>%w(view retryall exit changeLv msg assist false)
end
