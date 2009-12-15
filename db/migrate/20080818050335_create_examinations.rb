class CreateExaminations < ActiveRecord::Migration
  def self.up
    create_table :examinations do |t|
      t.integer :user_id
      t.string :test_id
      t.string :group_id
      t.integer :group_mark
      t.integer :ques_id
      t.float :ques_pass
      t.string :test_key
      t.string :examination_pkey

      t.timestamps
    end
  end

  def self.down
    drop_table :examinations
  end
end
