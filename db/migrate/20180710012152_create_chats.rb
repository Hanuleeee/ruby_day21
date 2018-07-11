class CreateChats < ActiveRecord::Migration[5.0]
  def change
    create_table :chats do |t|
      t.references    :user          #컬럼명이 저장되는게 아님.. 
      t.references    :chat_room
      
      t.text          :messege
      

      t.timestamps
    end
  end
end
