# 20180710_Day21

* jsp로 crud짜기  -> 기술면접

### pusher

* 실시간 채팅 혹은 그와 유사한 기능을 구현하기 위해 레일즈 에서는 ActionCable을 제공한다. 하지만 그보다 더 쉽게 외부 API를 이용하여 이 기능을 구현할 수 있다. 실제 ActionCable은 서버환경에 배포했을 때 더 많은 서버 셋팅을 거쳐야 하기에 pusher라고 하는 외부 API를 사용하고자 한다. 

* CUD Chatroom

* join
* Chat





## 채팅방 만들기

> https://github.com/pusher/pusher-http-ruby



### 필요한 Gem과 devise 설치

 

*Gemfile*

```ruby
# pusher
gem 'pusher'   #추가

# authentication
gem 'devise'

# key encrypt  
gem 'figaro'

# gem 'turbolinks', '~> 5'    # 주석 처리
```

> 터보링크 3군데에서 삭제! (Gemfile, *views/layouts/application.html.erb*)



`$ rails g devise:install`

`$ rails g devise users`





### db 설정 및 관계 설정

`$ rails g scaffold chat_room`

`$ rails g model chat`

`$ rails g model admission`



*db/migrate/chat_rooms*

```ruby
t.string    :title
t.string    :master_id
t.integer   :max_count
t.integer   :admission_count, default: 0  # 여기에 현재유저 몇명 입장해있는지 저장된다.
```



*db/migrate/chats*

```ruby
t.references    :user          #컬럼명이 저장되는게 아님.. 더 직관적으로 만들어줌 (외래키 지정)
t.references    :chat_room
t.text          :messege
```



*db/migrate/admissions*

```ruby
t.references    :chat_room  # 더 직관적으로 만들어줌 (외래키지정)
t.references    :user
```



* 관계 설정

*models/concerns/admission.rb*

```ruby
class Admission < ApplicationRecord
    belongs_to :user
    belongs_to :chat_room, counter_cache: true  #자동으로 admissions_count가 업데이트됨
end
```

> **counter_cache** 
>
> [관련문서](http://guides.rubyonrails.org/association_basics.html#options-for-belongs-to) 
>
> - 1:N 관계에 있을 때 1쪽에서 N을 몇개 가지고 있는지 파악하기 위해서 a.bs.count를 사용하게 되는데 이는 하나의 쿼리를 더 실행하는 결과를 낳는다. 쿼리의 숫자를 줄여 서버의 성능을 최적화 하는 것은 매우 중요하기 때문에 레일즈에서 제공하는 counter_cache 기능을 사용하게 된다. 1:N에서 1쪽에서는 DB에 N쪽의 갯수를 저장할 컬럼을 추가해주고, N쪽에서는 association 설정에서 `counter_cache: true` 를 추가적으로 주면 된다.
>
> The `:counter_cache` option can be used to make finding the number of belonging objects more efficien 



*models/concerns/chat.rb*

```ruby
class Chat < ApplicationRecord
    belongs_to :user
    belongs_to :chat_room
end
```



*models/concerns/chat_room.rb*

```ruby
class ChatRoom < ApplicationRecord
    has_many :admissions
    has_many :users, through: :admissions
    has_many :chats
end
```



*models/concerns/user.rb*

```ruby
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable
         
  has_many :admissions
  has_many :chat_rooms, through: :admissions
  has_many :chats
end

```



*app/views/chat_rooms/index.html.erb*

```erb
<% if user_signed_in? %>
<%= current_user.email %> / <%= link_to 'log out', destroy_user_session_path, method: :delete %>
<% else %>
<%= link_to 'log in', new_user_session_path %>
<% end %>


<hr> 

<h1>Chat Rooms</h1>

<table>
  <thead>
    <tr>
      <th>방제</th>
      <th>인원</th>
      <th>방장</th>
      <th></th>
    </tr>
  </thead>

  <tbody class="chat_room_list">
    <% @chat_rooms.reverse.each do |chat_room| %>
      <tr>
        <td><%= chat_room.title %></td>
        <td><span class="current<%= chat_room.id %>"><%= chat_room.admissions.size %></span>/<%= chat_room.max_count %></td>
        <td><%= chat_room.master_id %></td>
        <td><%= link_to 'Show', chat_room %></td>
      </tr>
    <% end %>
  </tbody>
</table>

<br>

<%= link_to 'New Chat Room', new_chat_room_path %>
```

*app/controllers/chat_rooms_controller.rb*

```ruby
...
def create
    @chat_room = ChatRoom.new(chat_room_params)
    @chat_room.master_id = current_user.email    #이 create를 만든사람이 방장이된다.
    respond_to do |format|
      if @chat_room.save
        @chat_room.user_admit_room(current_user)  #현재 유저(방장)가 이방에 참여한다는 것을 알려준다.
        ...        
      end
    end
end
```





```ruby
> rails c
> User.create(email: "aa@aa.aa", password: "123456")
> ChatRoom.create(title: "어서와 ^^", master_id: User.first.email, max_count: 5)
> u = User.first
> c = Chatroom.first
> Admission.create(user_id: u.id, chat_room_id: c.id)  
```

* 채팅방을 만드는 순간 조인테이블(*Admission)*을 만들어야한다. 

  

- 방이 만들어질 때, 방을 만든 현재 유저의 email이 chat_room의 속성 중 master_id로 들어가야한다.

*models.chat_room.rb*  에 추가

```ruby
class ChatRoom < ApplicationRecord
    has_many :admissions
    has_many :users, through: :admissions
    has_many :chats
    
    def user_admit_room(user) # 인스턴스메소드 # 채팅방이 만들어지자마자 유저랑 채팅방을 연결(그 유저가 채팅방에 참여한다)
        # ChatRoom이 하나 만들어 지고 나면(commit) 다음 메소드를 같이 실행한다.
        Admission.create(user_id: user.id , chat_room_id: self.id)
    end
    
end
```

- 위 코드는 다른 유저가 이 방에 들어와서 join했을 때에도 사용할 수 있다.



*controllers/concerns/chat_rooms_controller.rb*

```ruby
...
def create
    @chat_room = ChatRoom.new(chat_room_params)
    @chat_room.master_id = current_user.email    #이 create를 만든사람이 방장이된다.
    respond_to do |format|
      if @chat_room.save
        @chat_room.user_admit_room(current_user)  #현재 유저(방장)가 이방에 참여한다는 것을 알려준다.
        ...        
      end
    end
end

  def user_admit_room
    # 현재 유저가 있는 방에서 join 버튼을 눌렀을 때 동작하는 액션
    @chat_room.user_admit_room(current_user)
  end

  private
   ...
    # Never trust parameters from the scary internet, only allow the white list through.
    def chat_room_params
      params.fetch(:chat_room, {}).permit(:title, :max_count)  # parameter 넘겨줘야하니까 추가
    end
...
```



## pusher

PUSHER 페이지 들어가서 로그인 -> app 만들기

jquery 

> https://dashboard.pusher.com/apps/557884/getting_started



### Pusher를 사용하기 위한 설정을 추가 

`$ figaro install`

*config/application.yml*  : pusher에서 id, key, secret 가져와서 넣기



*config/initializers/pusher.rb*

```ruby
require 'pusher'

Pusher.app_id = ENV["pusher_app_id"]
Pusher.key = ENV["pusher_key"]
Pusher.secret = ENV["pusher_secret"]
Pusher.cluster = ENV["pusher_cluster"]
Pusher.logger = Rails.logger
Pusher.encrypted = true
```



*app/views/layout/application.html.erb* 

`<script src="https://js.pusher.com/4.1/pusher.min.js"></script>` 추가



*app/views/chat_rooms/index.html.erb*

```erb
...
<script>
  var pusher = new Pusher('<%= ENV["pusher_key"] %>', {
    cluster: "<%= ENV["pusher_cluster"] %>",
    encrypted: true
  });
</script>
```



### ChatRoom과 Admission에 새로운 row가 추가될 때(create가 발생할 때), Pusher를 통해 방이 생성되는 event가 발생했다고 알린다.

*app/models/chat_room.rb*  : 추가

```ruby
...
    after_commit :create_chat_room_notification, on: :create
    
    def create_chat_room_notification
        Pusher.trigger('chat_room', 'create', self.as_json) # 나 자신을 json으로 보냄
        # (channer_name, event_name, data)
    end
...
```

 -> index에서 처리함



*app/models/admission.rb*

```ruby
...
  after_commit :user_join_chat_room_notification, on: :create
  def user_join_chat_room_notification
    Pusher.trigger('chat_room', 'join', self.as_json)
    # Pusher.trigger('channel_name', 'event_name', sending data)
  end
...
```

- Pusher에 `chat_room`이라는 채널에서 `join`이라는 이벤트가 발생했음을 알리는 코드이다. 이제 *index*에서 이 채널에서 발생한 이벤트와 함께 동작하는 코드를 작성하면 된다.

- `after_commit`은 dbms에서 `commit transaction`이 발생한 이후에 메소드를 실행하는 것인데, create, update, destroy가 실행됐을 때만 사용할 수 있다.

  

pusher 사이트에서 코드 가져와서  *chat_rooms/index.html.erb* 에서 바꾸기 

*app/views/chat_rooms/index.html.erb*

```erb
...
  <tbody class= "chat_room_list">
...
<script>
$(document).on('ready', function(){
  // 방이 만들어졌을때, 방에 대한 데이터를 받아서 
  // 방 목록에 추가해주는 js function
  function room_created(data){
    $('.chat_room_list').prepend(`
      <tr>
        <td></td>
        <td>/</td>
        <td></td>
        <td></td>
      </tr>`);
      alert("새로운 방이 추가됨~");
  }
  var pusher = new Pusher('<%= ENV["pusher_key"] %>', {
    cluster: "<%= ENV["pusher_cluster"]%>",
    encrypted: true
  });
    
  var channel = pusher.subscribe('chat_room');
    channel.bind('create', function(data) {
    console.log("방만들어짐");
  });
  channel.bind('join', function(data) {
  console.log("유저가 들어감");
  });
});
  
</script>
```



- console에 정상적으로 로그가 찍히는 것을 확인할 수 있다. 이제 이때 동작할 function을 추가해주면 된다.

```javascript
  function room_created(data) {
    $('.chat_room_list').prepend(`
      <tr>
        <td>${data.title}</td>
        <td><span class="current${data.id}">0</span>/${data.max_count}</td>
        <td>${data.master_id}</td>
        <td><a href="/chat_rooms/${data.id}">Show</a></td>
      </tr>`);
  }
// 방이 만들어 질때, 리스트에 방 목록을 추가한다.
  
  function user_joined(data) {
    var current = $(`.current${data.chat_room_id}`);
    current.text(parseInt(current.text())+1);
  }
// 방에 들어갈 때, 현재 인원을 1 늘려준다.
```

- 처음 방이 만들어지면 현재 인원을 0을로 설정했다가, 방장이 입장하는 순간(만들어지는 동시에 방장은 해당 방에 입장하는 것으로) 0에서 1로 증가된다.



### show에서는 채팅방 내에서 발생하는 일들을 구현한다. 유저가 처음 방에 접속하면 현재 유저 목록과 join 버튼만 보인다. 먼저 방에 참여한 사람 리스트를 만들어보자.



*views/chat_rooms/show.html.erb*

```erb
My-id : <%= current_user.email %><br/>
<h3> 현재 로그인한 사람</h3>
<% @chat_room.users.each do |user| %>
    <p><%= user.email %></p>
<% end %>
<hr>
<%= link_to 'Join', join_chat_room_path(@chat_room), method: 'post', remote: true, class: "join_room" %> | 
<%= link_to 'Edit', edit_chat_room_path(@chat_room) %> |
<%= link_to 'Back', chat_rooms_path %>
```

- `chat_room`과 `user`는 M:N 관계로 연결되어 있기 때문에, `@chat_room.users`와 같은 코드를 사용할 수 있다.
- 이제 이 방에 참여하게 되면 해당 방 리스트에 join한 유저를 추가해주면 된다.
- `remote: true` 속성은 해당 버튼이 동작할 때, 요청을 ajax로 바꿔준다. 우리가 기존에 공부했던 jquery 코드로 작성했던 ajax 코드를 속성하나로 줄여준다. 



*config/routes.rb*

```ruby
resources :chat_rooms do
  member do
    post '/join' => 'chat_rooms#user_admit_room', as: 'join'  #추가(as 는 prefix 설정)
  end 
end
```



*app/controllers/chat_rooms_controller.rb*

```ruby
...
  def user_admit_room
    if current_user.joined_room?(@chat_room)
      render js: "alert('이미 참여한 방입니다!');"
    else
      @chat_room.user_admit_room(current_user)
    end
  end
...
```

