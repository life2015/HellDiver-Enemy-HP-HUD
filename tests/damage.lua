return function(make)
    local local_peer, other = "FEDCBA9876543210", "FEDCBA9876543211" -- differ beyond double precision
    local detector = make(function(kind) return kind == "enemy" end)
    local function row(unit, hp, peer, kind, descriptor, life)
        return {unit=unit, entity=unit+100, type=kind or "enemy", descriptor=descriptor or unit+1000,
                network=unit+2000, hp=hp, life=life or 0, creditor=peer or local_peer}
    end
    local function poll(rows, active, world, peer, manager)
        local records={};for _,r in ipairs(rows) do records[r.unit]=r end
        return detector:observe({manager=manager or 1,records=records},peer or local_peer,world or "mission",active)
    end
    assert(not poll({row(1,100)}), "initial state is baseline, not a hit")
    local event=poll({row(1,75)})
    assert(event and event.record.unit==1 and event.damage==25 and not event.dead)
    assert(not poll({row(1,75)}), "unchanged HP must not renew HUD")
    assert(not poll({row(1,50,other)}), "other peer must not activate HUD (full 64-bit comparison)")
    assert(not poll({row(1,40,"0000000000000000")}), "unknown credit must not activate HUD")
    assert(not poll({row(1,80)}), "healing is not an attack")
    event=poll({row(1,0,nil,nil,nil,2)})
    assert(event and event.dead and event.damage==80, "sampled lethal damage must activate death card")
    assert(not poll({row(1,0,nil,nil,nil,2)}), "death is terminal, not a repeating hit")
    -- New/respawned objects and skipped reads cannot inherit another baseline.
    assert(not poll({row(1,30,nil,nil,9999)}))
    assert(not poll({row(1,20,nil,nil,9998)}))
    assert(not detector:observe(nil,local_peer,"mission"))
    assert(not poll({row(1,10,nil,nil,9998)}))
    assert(not poll({row(1,5,nil,nil,9998)},nil,"new-mission"))
    assert(not poll({row(1,4,nil,nil,9998)},nil,"new-mission",other))
    assert(not poll({row(1,3,nil,nil,9998)},nil,"new-mission",other,2))
    detector:reset()
    poll({row(2,100,nil,"friendly"),row(3,100)})
    assert(not poll({row(2,30,nil,"friendly"),row(3,100)}), "players/props are excluded")
    assert(not poll({row(2,30,nil,"friendly")}), "vanished enemy has no observable attacker")
    assert(not poll({row(3,10)}), "reappearing target needs a new baseline")
    -- AoE selection is stable; another newly hit target can replace an idle one.
    detector:reset();poll({row(1,100),row(2,100)})
    event=poll({row(1,90),row(2,50)},1);assert(event.record.unit==1)
    event=poll({row(1,90),row(2,40)},1);assert(event.record.unit==2)
    detector:reset();poll({row(2,100),row(1,100)})
    event=poll({row(2,75),row(1,75)});assert(event.record.unit==1, "AoE tie must be deterministic")
    -- Known polling limits are deliberately explicit, not claimed to be solved.
    event=poll({row(1,65),row(2,75)})
    assert(event and event.record.unit==1, "stale local creditor can still attribute later environmental damage")
    assert(not poll({row(1,55,other),row(2,75)}), "last foreign creditor can mask an earlier local hit")
    local function partrow(hp, a, b, credit)
        local r=row(1,hp,credit);r.parts={[1]=a,[2]=b};return r
    end
    detector:reset();poll({partrow(100,300,200)})
    event=poll({partrow(100,250,200)})
    assert(event and event.damage==0 and event.part.index==1 and event.part.hp==250 and not event.dead,
        "part-only damage activates without reducing main health")
    event=poll({partrow(100,240,180)})
    assert(event.part.index==2 and event.part.damage==20, "largest drop selects one representative zone")
    assert(#event.parts==2 and event.parts[1].index==1 and event.parts[2].index==2,
        "all simultaneous part drops must reach the retained HUD, not only the largest")
    event=poll({partrow(100,230,170)})
    assert(event.part.index==1, "part tie uses lowest slot")
    event=poll({partrow(100,0,170)})
    assert(event.part.hp==0 and not event.dead, "depleted part must never imply enemy death")
    assert(not poll({partrow(100,0,160,other)}), "foreign part damage cannot activate")
    assert(not poll({partrow(100,-1,160)}), "negative values are not HP")
    assert(not poll({partrow(100,500,160)}), "healing/replacement is not damage")
    detector:reset();poll({partrow(100,300,200)})
    local r=partrow(100,250,200)
    assert(not detector:observe({manager=1,records={[1]=r}},local_peer,"mission",nil,false),
        "part_hud off restores main-health-only activation")
    detector:reset();poll({partrow(100,300,200)})
    assert(not detector:observe(nil,local_peer,"mission"))
    assert(not poll({partrow(100,250,200)}), "part damage across read gaps cannot be attributed")
    return "PASS: part-only damage, strongest-part selection, nonlethal zero, disable/reset handling, damage selection, full 64-bit credit, lethal hits, baselines/identity/read gaps, friend exclusion, deterministic AoE and documented attribution limits"
end
