# PS5 native app: FreeBSD-derived userland, static-only.
include(Platform/FreeBSD)
set(UNIX 1)
# Final native linking is handled by pack-soh.py; permit Ninja's archive dependency graph.
set(CMAKE_CXX_LINK_LIBRARY_USING_WHOLE_ARCHIVE_SUPPORTED TRUE)
set(CMAKE_CXX_LINK_LIBRARY_USING_WHOLE_ARCHIVE "LINKER:--whole-archive" "<LINK_ITEM>" "LINKER:--no-whole-archive")
