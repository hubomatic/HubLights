//
//  HubLightsApp.swift
//  HubLights
//
//  Created by Marc Prud'hommeaux on 2/12/21.
//

import SwiftUI
import MemoZ
import OSLog

private let log = Logger(subsystem: Bundle.main.bundleIdentifier!, category: #file)
private let loc = { NSLocalizedString($0, comment: "") }
@available(*, deprecated) private func wip<T>(_ t: T) -> T { t }

@main
struct HubLightsApp: App {
    /// A single application-wide model stored in the uset defaults
    @AppStorage("model") var modelStorage = ColdStorage(Model())

    @SceneBuilder var body: some Scene {
        WindowGroup {
            ContentView(model: $modelStorage.store)
        }
        .commands {
            SidebarCommands()
            ToolbarCommands()
            CommandGroup(before: CommandGroupPlacement.toolbar) {
                Button(loc("Refresh"), action: refreshSelection).keyboardShortcut("r", modifiers: [.command])
                Button(loc("Refresh All"), action: refreshSelectionAll).keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }
    }

    func refreshSelection() {
        log.debug(#function)
    }

    func refreshSelectionAll() {
        log.debug(#function)
    }
}

final class WarmStorage<T> : ObservableObject {
    @Published var wrappedValue: Binding<T>

    init(_ wrappedValue: Binding<T>) {
        self.wrappedValue = wrappedValue
    }

}

final class UndoProxy<T> : ObservableObject {
    @Published var wrappedValue: Binding<T>

    init(_ wrappedValue: Binding<T>) {
        self.wrappedValue = wrappedValue
    }

}

struct ContentView : View {
    @Environment(\.undoManager) var undoManager
    @Binding var model: Model
    // @StateObject private var proxy: UndoProxy<Model>

//    init(model: Binding<Model>) {
////        self.proxy = UndoProxy<Model>()
////        self._model = model
//        self._proxy = StateObject(wrappedValue: UndoProxy(model))
//    }

//    var undoableModel: Binding<Model> {
//        Binding { proxy.wrappedValue.wrappedValue } set: { newValue in
//            if let undoManager = undoManager, undoManager.isUndoRegistrationEnabled {
//                let previous = proxy.wrappedValue.wrappedValue
//                undoManager.registerUndo(withTarget: proxy) { proxy in
//                    proxy.wrappedValue.wrappedValue = previous
//                }
//            }
//
//            self.proxy.wrappedValue.wrappedValue = newValue
//        }
//    }

    var body: some View {
        // MainView(model: undoableModel)
        MainView(model: $model)
    }
}

struct MainView : View {
    @Binding var model: Model
    @State private var selection = Set<UUID>()
    @StateObject var status = StatusHolder()

    var body: some View {
        NavigationView {
            ConfigList(model: $model, selection: $selection)
                .frame(minWidth: 150)
                .toolbar {
                    ToolbarItem(id: "refresh", placement: ToolbarItemPlacement.automatic, showsByDefault: true) {
                        Button(action: refreshAll) {
                            Label(loc("Refresh"), systemImage: "arrow.triangle.2.circlepath.circle.fill")
                        }
                    }
                }

            ConfigEditorList(model: $model, selection: $selection)
                .frame(minWidth: 300)
        }
        .environmentObject(status)
        .onAppear {
            // when we first appear, select all the items
            if selection.isEmpty {
                selection = .init([model.configs.first?.id].compactMap({ $0 }))
            }
        }
    }

    func refreshAll() {
        log.debug(#function)
    }
}


struct ConfigList : View {
    @Binding var model: Model
    @Binding var selection: Set<UUID>

    var body: some View {
        Section(header: configsHeaderView, footer: configsFooterView, content: { configsContentView })
    }

    @ViewBuilder var configsHeaderView: some View {
        EmptyView()
        //wip(Text(loc("Repositories"))) // doesn't show as sidebar header
    }

    @ViewBuilder var configsFooterView: some View {
        Divider()
        HStack {
            Button(action: addConfig) {
                Image(systemName: "plus.circle.fill")
            }
            .help(loc("Add a new configuration"))
            Button(action: deleteSelection) {
                Image(systemName: "minus.circle.fill")
            }
            .disabled(selection.isEmpty)
            .help(loc("Remove the selected repositories"))
        }
        .buttonStyle(PlainButtonStyle())
        .padding(8)
    }

    @ViewBuilder var configsContentView: some View {
        List(selection: $selection) {
            ForEach(model.configs) { config in
                ConfigListItemView(config: $model[config: config.id])
            }
            .onDelete(perform: onDelete)
            .onMove(perform: onMove)
            .onInsert(of: [String(kUTTypeJSON)], perform: onInsert)
        }
    }

    func onMove(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        model.configs.move(fromOffsets: offsets, toOffset: destination)
    }

    func onDelete(indices: IndexSet) {
        model.configs.remove(atOffsets: indices)
        if !model.configs.isEmpty {
            selection = [model.configs[min(model.configs.count - 1, indices.min() ?? 0)].id]
        }
    }

    func onInsert(at offset: Int, itemProvider: [NSItemProvider]) {
        for provider in itemProvider {
            if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, error in
                    DispatchQueue.main.async {
//                        url.map { self.items.insert(Item(title: $0.absoluteString), at: offset) }
                    }
                }
            }
        }
    }

    func deleteSelection() {
        log.info(#function)
        let indices = model.configs.enumerated().filter({
            selection.contains($0.element.id)
        })
//        .map(\.self)

        onDelete(indices: .init(indices.map(\.offset)))
    }

    func addConfig() {
        let config = Config(title: loc("New Check"))
        model.configs.append(config)
        selection = [config.id]
    }
}

struct ConfigEditorList : View {
    @Binding var model: Model
    @Binding var selection: Set<UUID>

    var body: some View {
        ZStack {
            ScrollView {
                ForEach(model.configs) { config in
                    if selection.contains(config.id) {
                        ConfigEditorView(config: $model[config: config.id])
                        .lineLimit(1)
                        .padding()
                    }
                }
            }

            emptySelectionView()
        }
    }

    func emptySelectionView() -> some View {
        VStack {
            Spacer()
            if selection.isEmpty {
                HStack {
                    Spacer()
                    Text(loc("No Repositories Selected"))
                        .foregroundColor(Color.secondary)
                        .font(Font.title)

                    Spacer()
                }
            }
            Spacer()
        }
    }
}

struct ConfigEditorView : View {
    @Binding var config: Config
    @EnvironmentObject var status: StatusHolder

    private static let secondsFormatter = NumberFormatter()
    private static let intervalFormatter: DateIntervalFormatter = {
        let fmt = DateIntervalFormatter()
        fmt.dateStyle = .none
        fmt.timeStyle = .medium
        return fmt
    }()


    func selectionTitleView() -> some View {
        HStack {
            Label(config.listItemTitle, systemImage: config.enabledDefaulted == true ? "bolt.fill" : "bolt.slash.fill").font(.title)
            Spacer()
            Toggle(isOn: $config.enabledDefaulted) { EmptyView() }
                .disabled(config.serviceURL == nil)
                .toggleStyle(SwitchToggleStyle())
                .help(loc("Toggles whether this action check is enabled"))
        }
    }


    var body: some View {
        GroupBox(label: selectionTitleView()) {
            formBody
        }
    }

    var formBody: some View {
        Form {
            Group {
                TextField(config.listItemTitle, text: $config.titleDefaulted)
                    .formLabel(FormLabelView("Title:"))

                TextField(loc("Organization"), text: $config.org[defaulting: ""])
                    .formLabel(FormLabelView("Organization:"))

                TextField(loc("Repository"), text: $config.repo[defaulting: ""])
                    .formLabel(FormLabelView("Repository:"))

                TextField(loc("Branch (main, master)"), text: $config.branch[defaulting: ""])
                    .formLabel(FormLabelView("Branch:"))

//                Toggle(isOn: $config.enabledDefaulted) { FormLabelView("Enabled:") }
//                    .disabled(config.serviceURL == nil)
//                    .toggleStyle(SwitchToggleStyle())
            }

            HStack {
                // Slider(value: $config.checkIntervalDefaulted, in: 60...3600, step: 60)
                TextField(loc("Seconds"), value: $config.checkIntervalDefaulted, formatter: Self.secondsFormatter)
                    .frame(width: 50)
                Stepper(value: $config.checkIntervalDefaulted, in: 10...99_999, step: 1) { EmptyView() }
                formattedIntervalText.multilineTextAlignment(.trailing)
            }
            .formLabel(FormLabelView("Check Interval:"), compound: true)

            Divider()

            HStack {
                TextField(loc("GitHub API URL"), text: .constant(config.serviceURL?.absoluteString ?? ""))
                    .focusable(false)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(Color.secondary)
                    .font(Font.system(.body, design: .monospaced))
                Spacer()
                if let url = config.serviceURL {
                    Link(destination: url) { Text(Image(systemName: "link")) }
                        .help(loc("Open link in browser"))
                }
            }
                .formLabel(FormLabelView("Service URL:"))

            TextField("UUID:", text: .constant(config.id.uuidString))
                .focusable(false)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(Color.secondary)
                .font(Font.system(.body, design: .monospaced))
                .formLabel(FormLabelView("Identifier:"))

            GroupBox {
                HStack {
                    List {
                        switch status.results[config.id]?.checkAPIResponseZ {
                        case .none:
                            EmptyView()
                        case .failure(let x):
                            Text("Failure: \(x as NSError)")
                        case .success(let response):
                            ForEach(response.check_suites, content: responseItemView)
                        }
                    }

                    TextEditor(text: .constant(String(data: status.results[config.id] ?? .init(), encoding: .utf8) ?? ""))
                        .font(Font.system(.body, design: .monospaced))
                }
            }
            .frame(height: 150)

            HStack {
                Spacer()
                Button(loc("Check Now"), action: checkStatus)
                    .disabled(config.serviceURL == nil)
            }
        }
    }

    func responseItemView(_ response: CheckSuitesAPIResponse) -> some View {
        HStack {
            Text(response.conclusion?.rawValue ?? "")
            Divider()
            Text(response.status?.rawValue ?? "")
        }
    }

    func checkStatus() {
        log.debug(#function)
        status.check(config)
    }

    var formattedIntervalText: some View {
        HStack {
            Text(DateComponentsFormatter.localizedString(from: DateComponents(second: .init(self.config.checkIntervalDefaulted)), unitsStyle: .full) ?? "")
                .lineLimit(1)
                .foregroundColor(Color.secondary)
            Spacer()
        }
    }
}

extension Data {
    var checkAPIResponse: Result<CheckAPIResponse, Error> {
        Result { try JSONDecoder().decode(CheckAPIResponse.self, from: self) }
    }

    var checkAPIResponseZ: Result<CheckAPIResponse, Error> {
        memoz.checkAPIResponse
    }
}

struct FormLabelView : View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            //.font(.subheadline)
            //.bold()
    }
}

struct ConfigListItemView : View {
    @Binding var config: Config

    var body: some View {
        Label {
            Text(config.listItemTitle)
                .foregroundColor(config.enabledDefaulted ? nil : Color.secondary)
        } icon: {
            Image(systemName: "circle.fill")
                .renderingMode(.template)
                .foregroundColor(Bool.random() ? Color.red : Color.green)
        }
    }
}

//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView(model: .constant(Model()))
//    }
//}


/// Alignment guide for aligning a text field in a `Form`.
/// Thanks for Jim Dovey  https://developer.apple.com/forums/thread/126268
extension HorizontalAlignment {
    private enum ControlAlignment: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            return context[HorizontalAlignment.center]
        }
    }

    static let controlAlignment = HorizontalAlignment(ControlAlignment.self)
}

public extension View {
    /// Attaches a label to this view for laying out in a `Form`
    /// - Parameter view: the label view to use
    /// - Parameter labelView: the label to align with the `Form`
    /// - Parameter compound: if `true`, works around an issue in `SwiftUI.Form` where an embedded component (e.g., a `Stepper`) will have its label override the containing view
    /// - Returns: an `HStack` with an alignment guide for placing in a form
    func formLabel<V: View>(_ labelView: V, compound: Bool = false) -> some View {
        HStack {
            labelView.lineLimit(1)
            Group {
                if compound {
                    // works around an issue where any of self's controls that align to the form label will bunch up with `labelView`
                    Color.clear.overlay(self)
                } else {
                    self
                }
            }
            .alignmentGuide(.controlAlignment) { $0[.leading] }
        }
        .alignmentGuide(.leading) { $0[.controlAlignment] }

    }
}
