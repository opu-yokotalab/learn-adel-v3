class SeqLog < ActiveRecord::Base
  belongs_to :user
  belongs_to :ent_seq

  def self.getCurrentId(u_id)
    if seq = SeqLog.find(:first,:conditions=>"user_id = #{u_id}",:order=>"id Desc")
      return seq[:ent_seq_id]
    else
      return -1
    end
  end

end
