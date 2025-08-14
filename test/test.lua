local version = require "gameplay.version"
local persist = require "gameplay.persist"
local card = require "gameplay.card"

print("Full:", version.full())
print("Major:", version.major())
print(version.newer_than("0.2.1", "0.2.0"))
print(version.older_than("0.1.1", "0.2.0"))


card.init_deck()
card.setup()
print_r(card.draw_discard())
print_r(card.generate_newcard())
card.discard()
persist.save "test.dl"
