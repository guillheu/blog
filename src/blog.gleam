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
import lustre/element/svg

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
      html.html([], [
        html.head([], [
          html.script(
            [
              attribute.attribute("defer", ""),
              attribute.attribute(
                "data-project-id",
                "019ed586-c97e-7bf3-84d4-514adc9f3292",
              ),
              attribute.src("https://sdk.feedback.one/v0/core.min.js"),
            ],
            "",
          ),
        ]),
        html.body([], []),
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
      ..feedback_arrows()
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

fn feedback_arrows() -> List(Element(Nil)) {
  [
    svg.svg(
      [
        attribute.attribute("xml:space", "preserve"),
        attribute.attribute("viewBox", "0 0 415.262 415.261"),
        attribute.attribute("height", "100px"),
        attribute.attribute("width", "100px"),
        attribute.attribute("xmlns:xlink", "http://www.w3.org/1999/xlink"),
        attribute.attribute("xmlns", "http://www.w3.org/2000/svg"),
        attribute.id("Capa_1"),
        attribute.attribute("version", "1.1"),
        attribute.attribute("fill", "#000000"),
        attribute.class(
          "fixed right-15 top-[47%] -translate-y-1/2 hidden lg:block",
        ),
      ],
      [
        svg.g([], [
          svg.path([
            attribute.attribute(
              "d",
              "M414.937,374.984c-7.956-24.479-20.196-47.736-30.601-70.992c-1.224-3.06-6.12-3.06-7.956-1.224
		c-10.403,11.016-22.031,22.032-28.764,35.496h-0.612c-74.664,5.508-146.88-58.141-198.288-104.652
		c-59.364-53.244-113.22-118.116-134.64-195.84c-1.224-9.792-2.448-20.196-2.448-30.6c0-4.896-6.732-4.896-7.344,0
		c0,1.836,0,3.672,0,5.508C1.836,12.68,0,14.516,0,17.576c0.612,6.732,2.448,13.464,3.672,20.196
		C8.568,203.624,173.808,363.356,335.376,373.76c-5.508,9.792-10.403,20.195-16.523,29.988c-3.061,4.283,1.836,8.567,6.12,7.955
		c30.6-4.283,58.14-18.972,86.292-29.987C413.712,381.104,416.16,378.656,414.937,374.984z M332.928,399.464
		c3.673-7.956,6.12-15.912,10.404-23.868c1.225-3.061-0.612-5.508-2.448-6.12c0-1.836-1.224-3.061-3.06-3.672
		c-146.268-24.48-264.996-124.236-309.06-259.489c28.764,53.244,72.828,99.756,116.28,138.924
		c31.824,28.765,65.484,54.468,102.204,75.888c28.764,16.524,64.872,31.824,97.92,21.421l0,0c-1.836,4.896,5.508,7.344,7.956,3.672
		c7.956-10.404,15.912-20.196,24.48-29.376c8.567,18.972,17.748,37.943,24.479,57.527
		C379.44,382.94,356.796,393.956,332.928,399.464z",
            ),
          ]),
        ]),
      ],
    ),
    svg.svg(
      [
        attribute.attribute("xml:space", "preserve"),
        attribute.attribute("viewBox", "0 0 369.159 369.159"),
        attribute.attribute("height", "100px"),
        attribute.attribute("width", "100px"),
        attribute.attribute("xmlns:xlink", "http://www.w3.org/1999/xlink"),
        attribute.attribute("xmlns", "http://www.w3.org/2000/svg"),
        attribute.id("Capa_1"),
        attribute.attribute("version", "1.1"),
        attribute.attribute("fill", "#000000"),
        attribute.class(
          "fixed right-4 top-[57%] -translate-y-1/2 hidden lg:block",
        ),
      ],
      [
        svg.g([], [
          svg.path([
            attribute.attribute(
              "d",
              "M336.689,48.802c-1.836-5.508-10.403-6.12-11.628,0c-11.016,38.556-33.048,74.052-31.823,115.668
		c0,5.508,6.731,7.956,10.403,4.284c5.508-4.896,10.404-9.792,14.688-15.3c1.836,60.588,6.731,166.464-78.948,146.269
		c-4.896-1.225-8.568-3.061-12.24-4.896c20.809-19.584,29.988-47.124,12.24-77.724c-4.896-8.568-17.748-15.912-27.54-10.404
		c-19.584,9.792-21.42,36.72-18.972,55.692c1.836,13.464,7.344,24.479,15.3,32.436c-18.972,14.076-45.288,20.196-66.708,15.3
		c-17.748-4.283-28.152-14.688-32.436-28.151c9.792-6.12,18.36-12.24,25.092-18.36c20.808-18.36,39.168-69.156-3.06-75.888
		c-34.272-6.121-40.392,63.647-38.556,83.844c0,2.448,0.612,4.284,0.612,6.732c-15.912,7.344-33.66,11.016-49.572,7.956
		C0.09,277.078,3.15,202.414,29.466,179.77c3.06-2.448-1.224-7.956-4.284-5.508c-35.496,26.929-31.212,83.845-1.224,113.833
		c18.972,18.359,47.124,12.852,71.604,1.224c16.524,46.512,82.008,42.84,121.788,14.076c22.645,14.688,55.08,14.076,78.336-1.225
		c47.124-31.212,37.944-102.815,35.496-153.612c8.568,10.404,17.137,20.808,26.929,30.6c3.672,3.672,11.628,1.224,11.016-4.284
		C364.229,130.81,351.378,89.806,336.689,48.802z M107.19,234.238c1.836-9.18,9.792-39.78,25.704-33.048
		c23.868,10.404,6.732,38.556-3.672,50.796c-6.732,7.344-14.688,14.076-23.868,19.584
		C103.518,259.33,104.742,246.479,107.19,234.238z M205.11,239.746c1.224-8.567,7.344-30.6,21.42-18.359
		c6.731,5.508,7.344,17.136,7.344,24.479c0,15.912-6.12,29.376-16.524,40.393C206.334,274.631,202.662,256.271,205.11,239.746z
		 M320.778,130.81c-0.612,0.612-1.225,1.224-1.837,1.836c-3.672,6.732-7.956,11.628-12.852,16.524
		c3.06-27.54,15.912-53.244,25.092-79.56c9.792,27.54,17.748,55.692,22.032,84.456c-6.732-7.956-13.464-16.524-20.196-25.092
		C329.346,124.69,322.614,126.526,320.778,130.81z",
            ),
          ]),
        ]),
      ],
    ),

    svg.svg(
      [
        attribute.attribute("xml:space", "preserve"),
        attribute.attribute("viewBox", "0 0 394.873 394.873"),
        attribute.attribute("height", "100px"),
        attribute.attribute("width", "100px"),
        attribute.attribute("xmlns:xlink", "http://www.w3.org/1999/xlink"),
        attribute.attribute("xmlns", "http://www.w3.org/2000/svg"),
        attribute.id("Capa_1"),
        attribute.attribute("version", "1.1"),
        attribute.attribute("fill", "#000000"),
        attribute.class(
          "fixed right-2 top-[43%] -translate-y-1/2 hidden lg:block",
        ),
      ],
      [
        svg.g([], [
          svg.g([], [
            svg.path([
              attribute.attribute(
                "d",
                "M334.678,145.951c-19.584-38.556-59.364-58.752-99.756-67.32C134.553,57.211,43.365,121.471,0.525,208.375
			c-2.448,4.896,4.284,8.567,7.344,4.283C57.441,134.323,132.717,75.571,230.638,92.095
			c91.188,15.912,111.996,94.86,112.608,175.643c0,8.568,13.464,8.568,13.464,0C357.322,226.123,353.649,183.283,334.678,145.951z",
              ),
            ]),
            svg.path([
              attribute.attribute(
                "d",
                "M220.846,114.739c-44.676-5.508-88.74,13.464-126.685,35.496c-22.032,12.852-67.32,41.616-64.872,72.215
			c0,2.448,3.06,3.061,4.896,1.225c39.78-56.304,107.1-98.532,178.705-96.696c79.561,2.448,89.353,76.5,89.353,140.148
			c0,9.18,14.075,9.18,14.075,0C316.317,196.135,303.466,125.143,220.846,114.739z",
              ),
            ]),
            svg.path([
              attribute.attribute(
                "d",
                "M380.578,238.975c-6.12,13.464-25.704,69.156-47.124,66.096c-9.792-1.224-19.584-10.403-26.929-16.523
			c-12.852-9.792-25.703-20.196-39.168-29.376c-4.283-3.061-9.18,3.672-5.508,7.344c18.972,17.136,46.512,52.021,74.664,53.856
			c29.376,1.224,48.348-54.469,57.528-73.44C398.326,237.751,384.861,230.406,380.578,238.975z",
              ),
            ]),
          ]),
        ]),
      ],
    ),
  ]
}
