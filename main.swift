import Foundation

let filePath = "raw-model-output-multiples-example.md"
guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
    print("Error: Could not read \(filePath)")
    exit(1)
}

let blocks = content.components(separatedBy: "==================")
var predictions: [(label: String, probabilities: [String: Double])] = []

for block in blocks {
    let lines = block.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    
    guard let labelLine = lines.first(where: { $0.hasPrefix("label = String :") }) else {
        continue
    }
    let label = labelLine.replacingOccurrences(of: "label = String :", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    
    var probVal: Double = 0.0
    let searchKey = "\"\(label)\""
    if let probLine = lines.first(where: { $0.contains(searchKey) }) {
        let parts = probLine.components(separatedBy: "=")
        if parts.count == 2 {
            let valStr = parts[1].replacingOccurrences(of: "\"", with: "")
                                 .replacingOccurrences(of: ";", with: "")
                                 .trimmingCharacters(in: .whitespacesAndNewlines)
            if let val = Double(valStr) {
                probVal = val
            }
        }
    }
    
    predictions.append((label: label, probabilities: [label: probVal]))
}

// Pass to pipeline
let pipeline = GestureStreamPipeline(confidenceThreshold: 0.40)
for pred in predictions {
    pipeline.handlePrediction(label: pred.label, probabilities: pred.probabilities)
}

let tokens = pipeline.getTokens()
print("Pipeline Extracted Tokens: \(tokens)")

func runTranslation() async {
    do {
        let result = try await checkFM(input: tokens)
        print("Final FM Output: \(result)")
    } catch {
        print("Error: \(error.localizedDescription)")
    }
}

let sem = DispatchSemaphore(value: 0)
Task {
    await runTranslation()
    sem.signal()
}
sem.wait()
