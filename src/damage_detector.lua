-- Compare observed health, not mouse input or aim. A creditor may be stale and
-- only the last contributor survives a poll; this is not a per-bullet callback.
return function(is_enemy)
    local detector = {}
    function detector:reset()
        self.previous, self.world, self.peer, self.manager = nil, nil, nil, nil
    end
    function detector:observe(snapshot, peer, world, active_unit)
        if not snapshot or not peer or not world then self:reset() return nil end
        local previous = self.previous
        if self.world ~= world or self.peer ~= peer or self.manager ~= snapshot.manager then previous = nil end
        self.previous, self.world, self.peer, self.manager = snapshot.records, world, peer, snapshot.manager
        if not previous then return nil end -- baseline, never interpret an already injured spawn as our hit
        local best
        for unit, row in pairs(snapshot.records) do
            local old = previous[unit]
            if old and old.entity == row.entity and old.type == row.type
                and old.descriptor == row.descriptor and old.network == row.network
                and old.hp > 0 and old.life < 2 and row.hp < old.hp
                and row.creditor == peer and is_enemy(row.type) then
                local event = {record=row, previous_hp=old.hp,
                    damage=old.hp - math.max(0, row.hp), dead=row.hp <= 0 or row.life >= 2}
                local preferred = unit == active_unit
                local best_preferred = best and best.record.unit == active_unit
                if not best or (preferred and not best_preferred)
                    or (preferred == best_preferred and (event.damage > best.damage
                        or (event.damage == best.damage and unit < best.record.unit))) then best = event end
            end
        end
        return best
    end
    return detector
end
