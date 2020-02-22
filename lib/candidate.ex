defmodule Candidate do
	
def start(s) do
	s = State.role(s, :CANDIDATE)
	Candidate.start_election(s)
end

def start_election(s) do
	# increment term
	# reset voted for
	# vote for self
	# start timeout
	s = State.curr_term(s, s.curr_term + 1)
	s = State.votes(s, 1)
	s = State.voted_for(s, s.id)
	Server.broadcast(s, { :VOTE_REQ, s })
	timer_ref = Server.start_election_timeout(s)
	Candidate.next(s, timer_ref)
end

def next(s, timer_ref) do
	receive do
		# restart election (in case of split vote)
		{ :ELECTION_TIMEOUT } -> Candidate.start_election(s)

		# count up votes, transition into leader once enough
		{ :VOTE_REP, _} -> 
			Monitor.debug(s, "Candidate #{s.id} recieved vote")
			s = State.votes(s, s.votes + 1)
			# no need to check for greater than since transition occurs straight after reaching
			if s.votes == s.majority do
				Server.stop_timeout(timer_ref)
				Leader.start(s)
			else 
				Candidate.next(s, timer_ref)
			end 

		# respond to heartbeats
		# turn into Follower on valid heartbeat_req (valid leader found)
		{ :APPEND_REQ, :HEARTBEAT_REQ, server_state } ->
			{ replied, s } = Append.process_heartbeat_request(s, server_state)
			if replied do
				Server.stop_timeout(timer_ref)
				Follower.start(s)
			else
				Candidate.next(s, timer_ref)
			end

		# respond to vote requests
		{ :VOTE_REQ, server_state } ->
			Monitor.debug(s, 1, "Candidate #{s.id} received vote request from #{server_state.id}")
			{ _, s } = Vote.process_vote_request(s, server_state)
			Candidate.next(s, timer_ref)
	end
end

end