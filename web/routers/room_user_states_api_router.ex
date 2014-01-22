defmodule RoomUserStatesApiRouter do
  use Dynamo.Router
  use Ecto.Query
  import Cheko.RouterUtils

  prepare do
    authenticate_user!(conn)
  end

  get "/" do
    user_id = get_session(conn, :user_id)
    rooms = Repo.all(Room)

    room_user_states = Enum.map rooms, fn(room)->
      query = from r in RoomUserState, where: r.user_id == ^user_id and r.room_id == ^room.id
      result = Repo.all query
      if length(result) == 0 do
        room_user_state = RoomUserState.new(user_id: user_id, room_id: room.id, joined: false)
        Repo.create(room_user_state)
      else
        [room_user_state|_] = result
        room_user_state
      end
    end

    room_user_states_attributes = lc room_user_state inlist room_user_states do
      RoomUserState.public_attributes(room_user_state)
    end

    json_response([room_user_states: room_user_states_attributes], conn)
  end


  put "/:room_user_state_id" do
    room_user_state_id = conn.params[:room_user_state_id]
    user_id = get_session(conn, :user_id)

    {:ok, params} = conn.req_body
    |> JSEX.decode

    room_user_state_params = whitelist_params(params["room_user_state"], ["joined"])
    query = from r in RoomUserState, where: r.id == ^room_user_state_id and r.user_id == ^user_id
    [room_user_state] = Repo.get(RoomUserState, room_user_state_id)
    room_user_state = room_user_state.update(room_user_state_params)

    case RoomUserState.validate(room_user_state) do
      [] ->
        :ok = Repo.update(room_user_state)
        json_response [user: RoomUserState.public_attributes(room_user_state)], conn
      errors ->
        json_response [errors: errors], conn, 422
    end
  end

end