import blogatto
import blogatto/config
import blogatto/config/post as config_post
import blogatto/error
import blogatto/post.{type Post}
import contour
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleam/time/calendar
import gleam/time/duration
import gleam/time/timestamp
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

const github_path_prefix = ""

pub fn main() {
  let post_config =
    config_post.default()
    |> config_post.path("./blog")
    |> config_post.route_prefix("articles")
    |> config_post.template(article_template)
    |> config_post.code(fn(_, lang, children) {
      case lang {
        Some("gleam") -> {
          let code_text = case children {
            [element] -> element.to_string(element)
            _ ->
              panic as "Code blocks should only have one element (what the heck!)"
          }
          let stylized_html =
            contour.to_html(code_text)
            |> string.replace("&amp;gt;", ">")
            |> string.replace("&amp;lt;", "<")
            |> string.replace("&amp;quot;", "\"")
          element.unsafe_raw_html("", "code", [], stylized_html)
        }
        Some(_unknown_lang) | None -> html.code([], children)
      }
    })

  let cfg =
    config.new("https://blog.guillheu.dev")
    |> config.output_dir("./dist")
    |> config.static_dir("./static")
    |> config.post(post_config)
    |> config.route("/", home_view)

  case blogatto.build(cfg) {
    Ok(Nil) -> io.println("Site built successfully!")
    Error(err) -> io.println("Build failed: " <> error.describe_error(err))
  }
}

fn home_view(posts: List(Post(Nil))) -> Element(Nil) {
  let posts_links =
    list.sort(posts, fn(a, b) { timestamp.compare(b.date, a.date) })
    |> list.map(fn(p) {
      html.li([attribute.class("text-xl text-left proportional-nums")], [
        html.p([], [
          html.text(timestamp_to_short_string(p.date) <> " : "),
          html.a(
            [
              attribute.href(abs("/articles/") <> p.slug),
              attribute.class("link"),
            ],
            [
              element.text(p.title),
            ],
          ),
          html.text(" - " <> p.description),
        ]),
      ])
    })

  let home_title =
    html.div([], [
      html.h1([attribute.class("title text-4xl font-bold pt-3 pb-3")], [
        html.text("Hello, I'm Guillaume"),
      ]),
      html.p([attribute.class("pt-3 pb-6")], [
        html.text(
          "I'm a CompSci major and I do a bunch of stuff related to computers. Frequent interestests include Gleam, DevOps stuff, Nix, declarative anything and really ugly websites (as is painfully visible)",
        ),
        html.br([]),
        html.text(
          "I'll be posting techy stuff here. You can browse some articles:",
        ),
      ]),
    ])

  body_template(
    [home_title, ..posts_links],
    "blog.guillheu.dev",
    "Guillaume Heu's blog (:",
    option.Some("en"),
  )
}

fn body_template(
  contents: List(Element(Nil)),
  title: String,
  description: String,
  language: option.Option(String),
) -> Element(Nil) {
  let lang = option.unwrap(language, "en")

  html.html([attribute.lang(lang)], [
    html.head([], [
      html.meta([attribute.charset("UTF-8")]),
      html.meta([
        attribute.name("viewport"),
        attribute.content("width=device-width, initial-scale=1"),
      ]),
      html.title([], title),
      html.meta([
        attribute.name("description"),
        attribute.content(description),
      ]),
      html.link([
        attribute.rel("stylesheet"),
        attribute.href(abs("/css/style.css")),
      ]),
    ]),
    html.body([attribute.class("mx-auto")], [
      html.header([], [
        html.nav(
          [
            attribute.class(
              "flex navbar bg-base-200 justify-center text-xl gap-6 pl-4 pr-4",
            ),
          ],
          [
            html.a([attribute.href(abs("/")), attribute.class("link")], [
              element.text("← Home"),
            ]),
            html.a(
              [
                attribute.href("https://github.com/guillheu"),
                attribute.class("link"),
              ],
              [
                element.text("Github"),
              ],
            ),
            html.a(
              [
                attribute.href("https://resume.guillheu.dev"),
                attribute.class("link"),
              ],
              [
                element.text("Resume"),
              ],
            ),
          ],
        ),
      ]),
      html.main(
        [
          attribute.class(
            "text-center max-w-[800px] mx-auto pt-6 pl-4 pr-4 pb-12",
          ),
        ],
        contents,
      ),
      html.footer(
        [
          attribute.class(
            "footer bg-base-200 footer-center fixed bottom-0 left-0 right-0 pl-4 pr-4",
          ),
        ],
        [
          html.p([], [
            html.a(
              [
                attribute.class("link"),
                attribute.href("https://github.com/veeso/blogatto"),
              ],
              [
                element.text("Built with Blogatto"),
              ],
            ),
          ]),
        ],
      ),
    ]),
  ])
}

fn article_template(
  current_post: Post(Nil),
  _: List(Post(Nil)),
) -> Element(Nil) {
  let time_string =
    timestamp.to_rfc3339(current_post.date, duration.seconds(0))
    |> string.slice(11, 5)
  // -> "1970-01-01T00:16:40.123Z"

  let article =
    html.article([attribute.class("mx-auto")], [
      html.h1(
        [
          attribute.class("mx-auto pt-6 pb-1 text-5xl font-bold"),
        ],
        [
          element.text(current_post.title),
        ],
      ),
      html.p([attribute.class("prose prose-lg mx-auto pb-6")], [
        html.em([], [element.text(current_post.description)]),
        html.br([]),
        html.text(
          timestamp_to_string(current_post.date) <> " - " <> time_string,
        ),
      ]),
      html.div(
        [attribute.class("prose text-left max-w-none")],
        current_post.contents,
      ),
    ])

  body_template(
    [article],
    current_post.title,
    current_post.description,
    current_post.language,
  )
}

fn timestamp_to_string(ts: timestamp.Timestamp) -> String {
  let #(date, _time) = timestamp.to_calendar(ts, duration.seconds(0))
  let month = calendar.month_to_string(date.month)
  let day = case date.day {
    1 -> "1st"
    2 -> "2nd"
    3 -> "3rd"
    other -> int.to_string(other) <> "th"
  }
  month <> " " <> day <> " " <> int.to_string(date.year)
}

fn timestamp_to_short_string(ts: timestamp.Timestamp) -> String {
  let #(date, _time) = timestamp.to_calendar(ts, duration.seconds(0))
  let month =
    calendar.month_to_int(date.month)
    |> int.to_string
    |> string.pad_start(2, "0")
  let day = int.to_string(date.day) |> string.pad_start(2, "0")
  let year = int.to_string(date.year) |> string.drop_start(2)
  month <> "/" <> day <> "/" <> year
}

fn abs(path: String) -> String {
  github_path_prefix <> path
}
