import SwiftUI

struct ContentView: View {
    @Binding var document: MarkdownDocument

    var body: some View {
        MarkdownEditorView(markdown: $document.text)
            .frame(minWidth: 500, minHeight: 400)
    }
}
