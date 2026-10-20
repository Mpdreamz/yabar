import SwiftUI
import YabarCore

/// yabai's scratchpads: each an app's window (optionally one whose title matches) that floats at a place on the grid
/// and is shown and hidden with `yabar scratchpad <name>`. Greyed out without yabai's scripting addition.
struct ScratchpadsSection: View {
    let available: Bool
    @State private var scratchpads = Preferences.scratchpads

    var body: some View {
        Section {
            // By position, not by name: a row keyed by its name would be rebuilt (and lose focus) while it is typed.
            ForEach(scratchpads.indices, id: \.self) { index in
                let scratchpad = scratchpads[index]
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        field("name", $scratchpads[index].name, width: 80)
                        field("app", $scratchpads[index].app, width: 110)
                        field("title (regex)", Binding(
                            get: { scratchpads[index].title ?? "" },
                            set: { scratchpads[index].title = $0.isEmpty ? nil : $0 }
                        ), width: 100)
                        Button(role: .destructive) {
                            scratchpads.remove(at: index)
                        } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless)
                    }
                    HStack {
                        Text("Grid").foregroundStyle(.secondary)
                        field("6:6:1:1:4:4", $scratchpads[index].grid, width: 110)
                        if let problem = scratchpad.problem {
                            Text(problem).font(.caption).foregroundStyle(.red)
                        }
                    }
                }
            }
            Button("Add Scratchpad") {
                var name = "pad"
                var number = 1
                while scratchpads.contains(where: { $0.name == name }) {
                    number += 1
                    name = "pad\(number)"
                }
                scratchpads.append(Scratchpad(name: name, app: ""))
            }
        } header: {
            Text("Scratchpads")
        } footer: {
            Text(available
                ? "A new window of the app (matching the title, when set) becomes the scratchpad as it opens; or use "
                + "Make This Window a Scratchpad… in the menu. Show and hide it with yabar scratchpad <name>. The grid "
                + "is rows:cols:x:y:width:height."
                : "Scratchpads are yabai's own and need its scripting addition, which is not loaded (System Integrity "
                + "Protection partly disabled, then yabai --load-sa).")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .disabled(!available)
        .onChange(of: scratchpads) { _, new in Preferences.scratchpads = new }
    }

    private func field(_ prompt: String, _ text: Binding<String>, width: CGFloat) -> some View {
        TextField("", text: text, prompt: Text(prompt))
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .frame(width: width)
    }
}
