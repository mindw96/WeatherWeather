import AppKit
import WeatherCore

/// Uses the smoke-test preferences and connected screens; never changes display hardware.
enum DisplaySelectionValidation {
    static func run(overlays: OverlayController, completion: @escaping ([String: Bool]) -> Void) {
        var checks = preferenceChecks()
        let preferences = overlays.preferences
        let originalIDs = preferences.disabledDisplayIDs
        let originalMode = preferences.mode
        let originalPaused = preferences.paused
        let originalIntensity = preferences.intensity
        let originalSnowman = preferences.showSnowman
        let ids = overlays.displays.map(\.id)
        guard let firstID = ids.first else {
            checks["monitorSelectionHasConnectedDisplay"] = false
            completion(checks)
            return
        }
        checks["monitorIdentifiersDistinctAndStable"] = Set(ids).count == ids.count
            && overlays.displays.allSatisfy { $0.id == DisplayIdentity.key(for: $0.screen) }

        func later(_ action: @escaping () -> Void) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: action)
        }
        func finish() {
            preferences.disabledDisplayIDs = originalIDs
            preferences.mode = originalMode
            preferences.intensity = originalIntensity
            preferences.showSnowman = originalSnowman
            preferences.paused = originalPaused
            later { completion(checks) }
        }
        func checkRebuild() {
            // Rebuild exercises the notification's path, not physical unplug/replug.
            overlays.rebuildDisplays()
            later {
                checks["monitorScreenRebuildRetainsDisabledSelection"] = Set(overlays.displays.map(\.id)) == Set(ids)
                    && overlays.displays.allSatisfy { !preferences.isDisplayEnabled($0.id) && !$0.panel.isVisible && !$0.snowman.panel.isVisible }
                preferences.setDisplayEnabled(true, for: firstID)
                later {
                    checks["monitorReenableRestartsOnlySelectedDisplay"] = overlays.displays.allSatisfy {
                        $0.panel.isVisible == ($0.id == firstID)
                            && ($0.id == firstID ? !$0.view.simulation.particles.isEmpty : $0.view.simulation.particles.isEmpty)
                    }
                    preferences.mode = .snow
                    later {
                        checks["monitorSnowmanRespectsSelectedDisplay"] = overlays.displays.allSatisfy {
                            $0.snowman.panel.isVisible == ($0.id == firstID)
                        }
                        finish()
                    }
                }
            }
        }
        func checkAllOff() {
            preferences.paused = true
            preferences.disabledDisplayIDs = Set(ids)
            later {
                checks["monitorAllOffHidesPanelsAndSnowmen"] = overlays.displays.allSatisfy {
                    !$0.panel.isVisible && !$0.snowman.panel.isVisible
                }
                preferences.paused = false
                preferences.mode = .rain
                later {
                    checks["monitorResumeAndModeChangeKeepAllOff"] = overlays.displays.allSatisfy {
                        !$0.panel.isVisible && !$0.snowman.panel.isVisible && $0.view.simulation.mode == .rain
                    }
                    let particles = overlays.displays.map { $0.view.simulation.particles }
                    later {
                        checks["monitorAllOffSimulationDoesNotAdvance"] = particles.allSatisfy(\.isEmpty)
                            && overlays.displays.map { $0.view.simulation.particles } == particles
                        checkRebuild()
                    }
                }
            }
        }
        func selectOnly(_ index: Int) {
            guard index < ids.count else { checkAllOff(); return }
            let selected = ids[index]
            preferences.disabledDisplayIDs = Set(ids.filter { $0 != selected })
            later {
                checks["monitorOnlyDisplay\(index + 1)ShowsEffects"] = overlays.displays.allSatisfy {
                    $0.panel.isVisible == ($0.id == selected)
                        && $0.snowman.panel.isVisible == ($0.id == selected)
                }
                selectOnly(index + 1)
            }
        }

        preferences.disabledDisplayIDs = []
        preferences.mode = .snow
        preferences.intensity = 1
        preferences.showSnowman = true
        preferences.paused = false
        later {
            checks["monitorDefaultSelectionShowsEveryDisplay"] = overlays.displays.allSatisfy { $0.panel.isVisible }
            guard let first = overlays.displays.first(where: { $0.id == firstID }) else {
                checks["monitorSelectionHasConnectedDisplay"] = false
                finish()
                return
            }
            // Seed real simulation state so disabling must remove more than an empty panel.
            for _ in 0..<300 { first.view.simulation.update(deltaTime: 0.1) }
            checks["monitorDisabledFixtureHadParticles"] = !first.view.simulation.particles.isEmpty
            preferences.setDisplayEnabled(false, for: firstID)
            later {
                let simulation = first.view.simulation
                checks["monitorDisableHidesPanelAndSnowman"] = !first.panel.isVisible && !first.snowman.panel.isVisible
                checks["monitorDisableClearsAllWeatherState"] = simulation.particles.isEmpty
                    && simulation.piles.isEmpty && simulation.surfaces.isEmpty
                    && simulation.splashes.isEmpty && simulation.settledParticles.isEmpty
                let particles = simulation.particles, piles = simulation.piles
                let splashes = simulation.splashes, settled = simulation.settledParticles
                let activeBefore = overlays.displays.filter { $0.id != firstID }.map { $0.view.simulation.particles }
                later {
                    checks["monitorDisabledSimulationDoesNotAdvance"] = simulation.particles == particles
                        && simulation.piles == piles && simulation.splashes == splashes && simulation.settledParticles == settled
                    if !activeBefore.isEmpty {
                        checks["monitorOtherDisplaysKeepAnimating"] = overlays.displays.filter { $0.id != firstID }
                            .map { $0.view.simulation.particles } != activeBefore
                    }
                    selectOnly(0)
                }
            }
        }
    }

    private static func preferenceChecks() -> [String: Bool] {
        let name = "org.windowweather.display-selection-validation.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let preferences = Preferences(defaults: defaults)
        var checks = ["monitorPreferenceDefaultsToAllEnabled": preferences.disabledDisplayIDs.isEmpty
            && preferences.isDisplayEnabled("display-a")]
        preferences.setDisplayEnabled(false, for: "display-a")
        preferences.setDisplayEnabled(false, for: "disconnected-display")
        let restored = Preferences(defaults: defaults)
        checks["monitorSelectionSurvivesPreferenceReload"] = !restored.isDisplayEnabled("display-a")
        checks["monitorNewDisplayDefaultsEnabled"] = restored.isDisplayEnabled("new-display")
        restored.setDisplayEnabled(true, for: "display-a")
        let reenabled = Preferences(defaults: defaults)
        checks["monitorReenabledSelectionPersists"] = reenabled.isDisplayEnabled("display-a")
        checks["monitorDisconnectedSelectionIsRetained"] = !reenabled.isDisplayEnabled("disconnected-display")
        restored.setSnowmanPosition(SnowmanPosition(x: 0.3, y: 0.7), for: "display-a")
        restored.setDisplayEnabled(false, for: "display-a")
        checks["monitorSelectionPreservesWeatherAndSnowmanSettings"] = restored.mode == .snow
            && restored.accumulation && restored.showSnowman
            && Preferences(defaults: defaults).snowmanPosition(for: "display-a") == SnowmanPosition(x: 0.3, y: 0.7)
        return checks
    }
}
