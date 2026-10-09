-- Compare observed health, not mouse input or aim. A creditor may be stale and
-- only the last contributor survives a poll; this is not a per-bullet callback.
return function(is_enemy)
    local detector = {}
    function detector:reset()
        self.previous, self.world, self.peer, self.manager = nil, nil, nil, nil
    end
    function detector:observe(snapshot, peer, world, active_unit, parts_enabled, accepts, watched_unit)
        if not snapshot or not peer or not world then self:reset() return nil end
        local previous = self.previous
        if self.world ~= world or self.peer ~= peer or self.manager ~= snapshot.manager then previous = nil end
        self.previous, self.world, self.peer, self.manager = snapshot.records, world, peer, snapshot.manager
        if not previous then return nil end -- baseline, never interpret an already injured spawn as our hit
        local best, watched
        for unit, row in pairs(snapshot.records) do
            local old = previous[unit]
            if old and old.entity == row.entity and old.type == row.type
                and old.descriptor == row.descriptor and old.network == row.network
                and old.life < 2
                and row.creditor == peer and is_enemy(row.type) then
                local part, parts = nil, {}
                if parts_enabled ~= false and old.parts and row.parts then
                    for index = 1, 38 do
                        local before, after = old.parts[index], row.parts[index]
                        if type(before) == "number" and type(after) == "number"
                            and before > 0 and before <= 10000000 and after >= 0 and after < before then
                            local loss = before - after
                            local hit = {index=index, hp=after, damage=loss}
                            parts[#parts + 1] = hit
                            if not part or loss > part.damage then
                                part = hit
                            end
                        end
                    end
                end
                if row.hp < old.hp or part or row.life == 2 then
                    local event = {record=row, previous_hp=old.hp,
                        damage=math.max(0, old.hp - math.max(0, row.hp)),
                        dead=row.life == 2, part=part, parts=parts}
                    event.score = math.max(event.damage, part and part.damage or 0)
                    if unit == watched_unit then watched = event end
                    if not accepts or accepts(row, old) then
                        local preferred = unit == active_unit
                        local best_preferred = best and best.record.unit == active_unit
                        if not best or (preferred and not best_preferred)
                            or (preferred == best_preferred and (event.score > best.score
                                or (event.score == best.score and unit < best.record.unit))) then best = event end
                    end
                end
            end
        end
        return best, watched
    end
    return detector
end
