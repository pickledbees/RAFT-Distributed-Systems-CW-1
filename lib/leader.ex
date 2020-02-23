defmodule Leader do
	
def start(s) do
	s = State.role(s, :LEADER)
	Monitor.debug(s, 2, "Server #{s.id} becomes LEADER in term #{s.curr_term}")
	Leader.send_heartbeats(s)
end

def send_heartbeats(s) do
	Server.broadcast(s, { :APPEND_REQ, :HEARTBEAT_REQ, s })
	timer_ref = Process.send_after(s.selfP, { :HEARTBEAT }, s.config.append_entries_timeout)
	Leader.next(s, timer_ref)
end

def next(s, timer_ref) do
	receive do
		# heartbeat maintenance
		{ :HEARTBEAT } ->	Leader.send_heartbeats(s)

		# respond to heartbeats
		# if replied, another valid leader is present, thus turn into follower
		{ :APPEND_REQ, :HEARTBEAT_REQ, server_state } ->
			{ replied, s } = Append.process_heartbeat_request(s, server_state)
			if replied do
				Server.stop_timeout(timer_ref)
				Monitor.debug(s, 2, "Server #{s.id} steps down from LEADER")
				Follower.start(s)
			else
				Leader.next(s, timer_ref)
			end

		# respond to vote requests
		# if voted, another better leader is present, thus turn into follower
		{ :VOTE_REQ, server_state } ->
			{ voted, s } = Vote.process_vote_request(s, server_state)
			if voted do
				Server.stop_timeout(timer_ref)
				Monitor.debug(s, 2, "Server #{s.id} steps down from LEADER")
				Follower.start(s)
			else
				Leader.next(s, timer_ref)
			end
	end
end

end