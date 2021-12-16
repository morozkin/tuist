import Foundation
import TuistCore
import TuistGraph
import TuistSupport
import XcodeProj

/// Protocol that defines the interface of the workspace settings generation.
protocol WorkspaceSettingsDescriptorGenerating {
    /// Generates the workspace settings based on the workspace generation options.
    ///
    /// - Parameters:
    ///   - workspace: Workspace model.
    func generateWorkspaceSettings(workspace: Workspace) -> WorkspaceSettingsDescriptor?
}

final class WorkspaceSettingsDescriptorGenerator: WorkspaceSettingsDescriptorGenerating {
    func generateWorkspaceSettings(workspace: Workspace) -> WorkspaceSettingsDescriptor? {
        guard !workspace.generationOptions.isEmpty else {
            return nil
        }

        let generationBehavior = workspace.generationOptions
            .map { option -> Workspace.GenerationOptions.AutomaticSchemeMode? in
                switch option {
                case let .automaticXcodeSchemes(behavior):
                    return behavior
                }
            }
            .first
            .map(\.?.value)

        if let generationBehavior = generationBehavior {
            return WorkspaceSettingsDescriptor(automaticXcodeSchemes: generationBehavior)
        } else {
            return nil
        }
    }
}