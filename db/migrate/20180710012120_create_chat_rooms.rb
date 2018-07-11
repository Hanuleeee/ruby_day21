class CreateChatRooms < ActiveRecord::Migration[5.0]
  def change
    create_table :chat_rooms do |t|
      t.string    :title
      t.string    :master_id
      
      t.integer   :max_count
      t.integer   :admissions_count, default: 0  # 여기에 현재유저 몇명 입장해있는지 저장될거임

      t.timestamps
    end
  end
end
