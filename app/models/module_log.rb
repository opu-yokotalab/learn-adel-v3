class ModuleLog < ActiveRecord::Base
	belongs_to :ent_seq
	belongs_to :ent_module
	
#	def self.getCurrentModule(u_id , s_id)
#		if mod = ModuleLog.find(:first,:conditions=>"user_id = #{u_id} and ent_seq_id = #{s_id}",:order=>"id Desc")
	def self.getCurrentModule(s_id)
		if mod = ModuleLog.find(:first,:conditions=>"ent_seq_id = #{s_id}",:order=>"id Desc")
			return mod[:ent_module_id]
		else
			return -1
		end
	end
	
#	validates_presence_of :user_id, :ent_seq_id, :ent_module_id
	validates_presence_of :ent_seq_id, :ent_module_id
end