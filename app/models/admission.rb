class Admission < ApplicationRecord
    belongs_to :user
    belongs_to :chat_room, counter_cache: true  #자동으로 admissions_count가 업데이트됨
    
    after_commit :user_joined_chat_room_notification, on: :create
    
    def user_joined_chat_room_notification
       Pusher.trigger('chat_room', 'join', {chat_room_id: self.chat_room_id, email: self.user.email}.as_json) 
    end
end
