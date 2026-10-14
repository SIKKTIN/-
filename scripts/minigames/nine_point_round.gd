extends RefCounted

# Pure rules and accounting. Neither UI animation nor NPCs inspect opponents' cards.
const STAKES := [0, 5, 10, 20, 50]
var rng := RandomNumberGenerator.new()
var state := "betting"
var hands: Array = []
var names: Array = []
var bank_before: Array = []
var bank_after: Array = []
var deck: Array[int] = []
var stake := 0
var pot := 0
var winners: Array[int] = []
var payouts: Array[int] = []
var forfeited := false
var npc_actions: Array = []

func _init():
	rng.randomize()

static func card_value(card: int) -> int:
	var rank := card % 13 + 1
	return rank if rank < 10 else 0

static func points(cards: Array) -> int:
	var total := 0
	for card in cards: total += card_value(int(card))
	return total % 10

static func card_label(card: int) -> String:
	var rank := card % 13 + 1
	return ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"][rank-1]

func start(players: Array, amount: int, balances: Array) -> String:
	if state != "betting": return "上一局尚未结束。"
	if players.size() < 2 or players.size() > 4 or balances.size() != players.size(): return "牌局需要2—4人。"
	if amount not in STAKES: return "请选择有效押注档位。"
	for i in balances.size():
		if int(balances[i]) < amount: return "%s的钱不够本局押注。" % str(players[i])
	names = players.duplicate()
	stake = amount
	pot = amount * names.size()
	bank_before = balances.duplicate()
	bank_after = balances.map(func(value): return int(value)-stake)
	deck.clear()
	for card in 52: deck.append(card)
	for i in range(51, 0, -1):
		var other := rng.randi_range(0, i)
		var saved := deck[i]
		deck[i] = deck[other]
		deck[other] = saved
	hands.clear()
	for i in names.size(): hands.append([deck.pop_back()])
	payouts.clear()
	for i in names.size(): payouts.append(0)
	winners.clear()
	npc_actions.clear()
	forfeited = false
	state = "decision"
	return ""

func decide(draw_second: bool) -> bool:
	if state != "decision": return false
	if draw_second: hands[0].append(deck.pop_back())
	_finish()
	return true

func draw_for_reveal() -> bool:
	if state != "decision": return false
	hands[0].append(deck.pop_back())
	state = "revealing"
	return true

func finish_reveal() -> bool:
	if state != "revealing": return false
	_finish()
	return true

func forfeit() -> bool:
	if state not in ["decision", "revealing"]: return false
	forfeited = true
	_finish()
	return true

func _finish():
	for i in range(1, hands.size()):
		# A modestly risky second opponent draws on 5; the others stand there.
		var draw_second: bool = points(hands[i]) <= (5 if i == 2 else 4)
		if draw_second: hands[i].append(deck.pop_back())
		npc_actions.append("要牌" if draw_second else "停牌")
	var best := -1
	for i in hands.size():
		if i == 0 and forfeited: continue
		var score := points(hands[i])
		if score > best:
			best = score
			winners.clear()
		if score == best: winners.append(i)
	var share := int(pot / winners.size())
	for index in winners: payouts[index] = share
	# Integer wallets cannot split a coin. Randomize remainder recipients,
	# without creating or discarding money or systematically favoring the player.
	var remainder := pot % winners.size()
	var start_index := rng.randi_range(0, winners.size()-1)
	for i in remainder: payouts[winners[(start_index+i) % winners.size()]] += 1
	for i in bank_after.size(): bank_after[i] += payouts[i]
	state = "result"

func result_text() -> String:
	if state != "result": return ""
	if forfeited: return "你已弃局，押注归入奖池。"
	var delta := int(bank_after[0]) - int(bank_before[0])
	if stake == 0: return "练习局 · " + ("你获胜" if 0 in winners else "本局未获胜")
	if winners.size() > 1 and 0 in winners: return "并列获胜 · 净收益 %+d" % delta
	return ("你获胜" if 0 in winners else "本局未获胜") + " · 净收益 %+d" % delta
