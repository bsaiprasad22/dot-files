import embroidery._
import java.nio.file.{Files, Paths}
import java.nio.charset.StandardCharsets

object Main {
  def main(args: Array[String]): Unit = {
    // println("Hello, Scala!".toAsciiArt)

    // Optional: render from image
    val art = ImagePath("src/main/resources/snorlax.png").toAsciiArtColored.linesIterator.toList
    // println(art)
    val luaString =
      "return {\n" +
      art.map(line => s"""  "${line.replace("\\", "\\\\").replace("\"", "\\\"")}",\n""").mkString +
      "}\n"

    Files.write(Paths.get("ascii.lua"), luaString.getBytes(StandardCharsets.UTF_8))
  }
}

