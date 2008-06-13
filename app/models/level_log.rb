class LevelLog < ActiveRecord::Base
	belongs_to :ent_seq
	
	def self.getCurrentLevel(u_id,ent_seq_id)
		if level = LevelLog.find(:first,:conditions=>"user_id = #{u_id} and ent_seq_id = #{ent_seq_id}",:order=>"id Desc")
			return level[:level].to_s
		else
			LevelLog.create(:user_id=>"#{u_id}", :level=>'1', :ent_seq_id =>"#{ent_seq_id}")
			return "1"
		end
	end
	
	validates_inclusion_of :level, :in=>(1..5)
end