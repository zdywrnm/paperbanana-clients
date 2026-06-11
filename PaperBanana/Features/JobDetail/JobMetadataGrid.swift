import SwiftUI

struct JobMetadataGrid: View {
  let job: Job

  private var columns: [GridItem] {
    [GridItem(.adaptive(minimum: 150), alignment: .topLeading)]
  }

  var body: some View {
    LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
      ForEach(job.metadataItems) { item in
        VStack(alignment: .leading, spacing: 2) {
          Text(item.label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
          Text(item.value)
            .font(.caption)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
        }
      }
    }
  }
}
