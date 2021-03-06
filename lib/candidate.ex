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
	Monitor.debug(s, 2, "Server #{s.id} is CANDIDATE in term #{s.curr_term}")
	
	Monitor.log(s, "Server #{s.id} is CANDIDATE")

	# vote for self
	s = State.votes(s, 1)
	s = State.voted_for(s, s.id)
	# send out votes, note: will reject self vote
	Server.broadcast(s, { :VOTE_REQ, s })
	# set election timeout
	timer_ref = Server.start_election_timeout(s)
	Candidate.next(s, timer_ref)
end

def next(s, timer_ref) do
	receive do
		# restart election (in case of split vote)
		{ :ELECTION_TIMEOUT } -> Candidate.start_election(s)

		# count up votes, transition into leader once enough
		{ :VOTE_REP, server_state } -> 
			# Monitor.log_action(s, server_state, "receieved vote from")
			
			s = State.votes(s, s.votes + 1)
			# no need to check for greater than since transition occurs straight after reaching
			if s.votes == s.majority do
				Server.stop_timeout(timer_ref)
				Leader.start(s)
			else 
				Candidate.next(s, timer_ref)
			end 

		# respond to vote requests
		# if voted, candidate is outdated since it could not have voted after voting for itself
		{ :VOTE_REQ, candidate } ->
			{ voted , s } = Vote.process_vote_request(s, candidate)
			if voted do
				Server.stop_timeout(timer_ref)
				Follower.start(s)
			else
				Candidate.next(s, timer_ref)
			end

		# look out for leaders
		{ :APPEND_REQ, leader } ->
			# if valid leader present, process request and step down
			if s.curr_term <= leader.curr_term do
				s = Append.process_append_entries_request(s, leader)
				Follower.start(s)
			else
				# else reject request and continue as candidate
				send leader.selfP, { :APPEND_REP, s.curr_term, false }
				Candidate.next(s, timer_ref)
			end

		# DEV listeners
		#----------------------------------------------------------------------------

		# respond to dummy heartbeats
		# turn into Follower on valid heartbeat_req (valid leader found)
		{ :HEARTBEAT_REQ, server_state } ->
			{ replied, s } = Append.process_heartbeat_request(s, server_state)
			if replied do
				Server.stop_timeout(timer_ref)
				Monitor.log(s, "CANDIDATE #{s.id} stepped down")
				Follower.start(s)
			else
				Candidate.next(s, timer_ref)
			end
	end
end

end