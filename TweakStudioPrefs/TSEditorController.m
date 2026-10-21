#import "TSEditorController.h"

@interface TSEditorController ()
@property (nonatomic, copy) NSString *projectPath;
@property (nonatomic, copy) NSString *currentFile;
@property (nonatomic, strong) UITextView *editor;
@property (nonatomic, strong) UISegmentedControl *filePicker;
@property (nonatomic, copy) NSArray<NSString *> *editableFiles;
@end

@implementation TSEditorController

- (instancetype)initWithProjectPath:(NSString *)projectPath {
    self = [super initWithNibName:nil bundle:nil];
    if (self) _projectPath = [projectPath copy];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Source Editor";
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Save" style:UIBarButtonItemStyleDone target:self action:@selector(saveFile)];

    NSString *primary = [NSFileManager.defaultManager fileExistsAtPath:[self.projectPath stringByAppendingPathComponent:@"Tweak.xm"]] ? @"Tweak.xm" : @"main.m";
    NSMutableArray<NSString *> *files = [NSMutableArray arrayWithObjects:primary, @"Makefile", @"control", nil];
    NSArray<NSString *> *projectFiles = [NSFileManager.defaultManager contentsOfDirectoryAtPath:self.projectPath error:nil];
    for (NSString *file in projectFiles) {
        if ([file.pathExtension.lowercaseString isEqualToString:@"plist"] && ![files containsObject:file]) { [files addObject:file]; break; }
    }
    self.editableFiles = files;
    self.filePicker = [[UISegmentedControl alloc] initWithItems:self.editableFiles];
    self.filePicker.selectedSegmentIndex = 0;
    [self.filePicker addTarget:self action:@selector(fileChanged:) forControlEvents:UIControlEventValueChanged];
    self.filePicker.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.filePicker];

    self.editor = [[UITextView alloc] initWithFrame:CGRectZero];
    self.editor.translatesAutoresizingMaskIntoConstraints = NO;
    self.editor.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightRegular];
    self.editor.autocorrectionType = UITextAutocorrectionTypeNo;
    self.editor.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.editor.spellCheckingType = UITextSpellCheckingTypeNo;
    self.editor.backgroundColor = UIColor.secondarySystemBackgroundColor;
    self.editor.layer.cornerRadius = 12;
    self.editor.layer.masksToBounds = YES;
    self.editor.textContainerInset = UIEdgeInsetsMake(14, 12, 14, 12);
    [self.view addSubview:self.editor];

    UILabel *hint = [UILabel new];
    hint.translatesAutoresizingMaskIntoConstraints = NO;
    hint.text = @"Edits are saved directly into this project's files.";
    hint.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    hint.textColor = UIColor.secondaryLabelColor;
    [self.view addSubview:hint];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.filePicker.topAnchor constraintEqualToAnchor:safe.topAnchor constant:14],
        [self.filePicker.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [self.filePicker.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [self.editor.topAnchor constraintEqualToAnchor:self.filePicker.bottomAnchor constant:14],
        [self.editor.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:12],
        [self.editor.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-12],
        [self.editor.bottomAnchor constraintEqualToAnchor:hint.topAnchor constant:-10],
        [hint.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [hint.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [hint.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-8]
    ]];
    [self loadFile:primary];
}

- (void)fileChanged:(UISegmentedControl *)sender {
    [self saveCurrentFileSilently];
    if (sender.selectedSegmentIndex < self.editableFiles.count) [self loadFile:self.editableFiles[sender.selectedSegmentIndex]];
}

- (void)loadFile:(NSString *)file {
    self.currentFile = file;
    NSString *path = [self.projectPath stringByAppendingPathComponent:file];
    NSError *error = nil;
    NSString *text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    self.editor.text = text ?: [NSString stringWithFormat:@"// %@ is not part of this project.\n", file];
}

- (void)saveCurrentFileSilently {
    if (!self.currentFile || !self.editor) return;
    NSString *path = [self.projectPath stringByAppendingPathComponent:self.currentFile];
    NSError *error = nil;
    [self.editor.text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (error) NSLog(@"[TweakStudio] Save failed: %@", error.localizedDescription);
}

- (void)saveFile {
    NSError *error = nil;
    NSString *path = [self.projectPath stringByAppendingPathComponent:self.currentFile ?: @""];
    [self.editor.text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error];
    NSString *title = error ? @"Could not save" : @"Saved";
    NSString *message = error ? error.localizedDescription : [NSString stringWithFormat:@"%@ updated.", self.currentFile];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
