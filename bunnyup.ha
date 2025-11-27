// Bunnyup - ASCII Art Terminal App
// A simple program that displays random ASCII art from user files or defaults

use fmt;
use os;
use fs;
use io;
use getopt;
use crypto::random;
use strings;

// Define the directory where user ASCII art files are stored
def ART_DIR: str = "bunnies";

// Default ASCII art pieces
const DEFAULT_ART: [_]str = [
	`               ((\
            ___ \\ '--._
         .'~   ~'    o  )
        /    \   '. __.'
       _|    /_  \ \_\_
      {_\______\-'\__\_\`,

	`     \\
      \\_
      ( _\
      / \__
     / _/~"~
    {\  )_
     ~"""~`,

	`                              __
                     /\    .-" /
                    /  ; .'  .' 
                   :   :/  .'   
                    \  ;-.'     
       .--""""--..__/     ~.    
     .'           .'    ~o  \   
    /                    ~   ;  
   :                  \      :  
 .-;        -.         ~.__.-'  
:  ;          \     ,   ;       
'._:           ;   :   (        
    \/  .__    ;    \   ~-.     
     ;     "-,/_..--"~-..__)    
     '""--.._:`,
];

export fn main() void = {
	// Parse command-line arguments
	const cmd = getopt::parse(os::args,
		"Display random ASCII art from files or defaults",
		('n', "nodefaults", "Don't use default art if folder is empty"),
	);
	defer getopt::finish(&cmd);

	// Check for --nodefaults flag
	let use_defaults = true;
	for (let i = 0z; i < len(cmd.opts); i += 1) {
		const opt = cmd.opts[i];
		if (opt.0 == 'n') {
			use_defaults = false;
		};
	};

	// Collect all art pieces (from files and/or defaults)
	let art_pieces: []str = [];
	let files_read = 0z;
	
	// Try to read files from directory
	match (os::iter(ART_DIR)) {
	case let dir: *fs::iterator =>
		// Directory exists, read files
		defer fs::finish(dir);
		
		for (true) {
			const entry = match (fs::next(dir)) {
			case let e: fs::dirent =>
				yield e;
			case done =>
				break;
			case fs::error =>
				break;
			};

			// Skip directories
			if (entry.ftype == fs::mode::DIR) {
				continue;
			};

			// Build filepath - asprintf returns a result type
			const filepath = match (fmt::asprintf("{}/{}", ART_DIR, entry.name)) {
			case let s: str =>
				yield s;
			case =>
				continue; // Skip this file if we can't build the path
			};
			
			match (os::open(filepath)) {
			case let file: io::file =>
				defer io::close(file)!;
				
				match (io::drain(file)) {
				case let content: []u8 =>
					match (strings::fromutf8(content)) {
					case let s: str =>
						match (append(art_pieces, s)) {
						case void =>
							files_read += 1;
						case =>
							free(s);
						};
					case =>
						free(content);
					};
				case =>
					void;
				};
			case =>
				void;
			};
			
			free(filepath);
		};
	case =>
		// Directory doesn't exist, that's okay
		void;
	};

	// Add defaults if enabled
	if (use_defaults) {
		for (let i = 0z; i < len(DEFAULT_ART); i += 1) {
			match (append(art_pieces, DEFAULT_ART[i])) {
			case void =>
				yield;
			case =>
				void;
			};
		};
	};

	// Check if we have any art
	if (len(art_pieces) == 0) {
		fmt::println("Empty :(")!;
		fmt::println("Put some files in the 'bunnies' folder")!;
		os::exit(1);
	};

	// Generate random index
	let buf: [4]u8 = [0...];
	random::buffer(buf);
	const random_num = buf[0]: u32 | (buf[1]: u32 << 8) | 
	                   (buf[2]: u32 << 16) | (buf[3]: u32 << 24);
	const random_index = random_num % len(art_pieces): u32;

	// Print the selected art
	fmt::println(art_pieces[random_index])!;

	// Clean up dynamically allocated strings (only the files we read)
	for (let i = 0z; i < files_read; i += 1) {
		free(art_pieces[i]);
	};
	free(art_pieces);
};
