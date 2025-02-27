import SwiftUI

struct ContentView: View {
    @State private var showOCRScanner = false

    var body: some View {
        VStack {
            Text("MRZ OCR Scanner")
                .font(.largeTitle)
                .padding()

            Button(action: {
                showOCRScanner = true
            }) {
                Text("Start Scanning")
                    .font(.title2)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .sheet(isPresented: $showOCRScanner) {
            MRZOCRViewControllerWrapper()
        }
    }
}

struct MRZOCRViewControllerWrapper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> MRZOCRViewController {
        return MRZOCRViewController()
    }
    
    func updateUIViewController(_ uiViewController: MRZOCRViewController, context: Context) {}
}

#Preview {
    ContentView()
}
