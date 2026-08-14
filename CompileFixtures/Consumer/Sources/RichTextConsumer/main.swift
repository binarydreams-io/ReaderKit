import RichText

let blocks = try RichText(html: "<p>A native article block.</p>").blocks()

print("RichText consumer: \(blocks.count) block")
