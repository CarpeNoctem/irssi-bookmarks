irssi-bookmarks
===============

Irssi Bookmarks - Manages a list of bookmarks within irssi.

Bookmark urls to follow up on later.

README from the head of the script:
<pre>
Note: For compatability with existing irssi commands, aliases, and other scripts,
      bookmarks.pl uses the below commands. Personally, I've aliased these as /b, /lb,
      /shrink, and /rmb, respectively. (Since I have autosave on, I don't really use the last 3 cmds.)

Commands:
        /bookmark &lt;-s&gt; &lt;URL&gt; - bookmarks &lt;URL&gt;, or the last seen URL in the current window
                               if -s option is used, bookmarks it in shortened form.
        /bookmarks &lt;-a|-s|search_term&gt;
                             - lists all saved bookmarks - '-a' option forces listing of long links,
                               while '-s' forces only shortened links to be listed (when available).
                               Additionally, the argument may be a search term.
        /bookmark_shorten &lt;URL&gt;
        /bshorten &lt;URL&gt;
                             - prints shortened &lt;URL&gt; and adds it to bookmarks if not already there.
                               if already in bookmarks, adds shortened URL next to it
        /bookmark_rm &lt;URL&gt;   - removes &lt;URL&gt; from bookmarks. if no url provided, removes last bookmarked url.
        /bookmarks_save      - explicitly save current bookmarks to file
        /bookmarks_reload    - (re)load bookmarks from file in addition to any already in memory (excluding duplicates)
        /bookmarks_clear     - clears the list of bookmarks (CAREFUL - Will clear from file as well if autosave
                               is enabled. The list will be printed first, however, as long as listonclear is ON)

Settings:
        bookmarks_file      - default: '~/.irssi/irssi.bookmarks'
        bookmarks_shortener - default: 'is.gd' (http://is.gd)
        bookmarks_hide_long - default: OFF - don't show long url if shortened one exists (otherwise shows both)
        bookmarks_autosave  - default: ON - update file each time a bookmark is added.
        bookmarks_list_on_clear - default: ON - prints bookmarks before clearing the list

TODO:
    * implement url shortening for other services: tinyurl, goo.gl, bit.ly
</pre>