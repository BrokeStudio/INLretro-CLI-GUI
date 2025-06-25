#if __APPLE__
#include <TargetConditionals.h>
#if TARGET_OS_MAC
#include <libgen.h>
#include <mach-o/dyld.h>

static int getExecutablePath(std::string &outputPath)
{
  outputPath.clear();

// #ifdef WIN32
//   char fullPath[2048];
//   char driveLetter[3];
//   char directory[2048];
//   char finalPath[2048];

//   GetModuleFileNameA(NULL, fullPath, 2048);
//   _splitpath(fullPath, driveLetter, directory, NULL, NULL);
//   snprintf(finalPath, sizeof(finalPath), "%s%s", driveLetter, directory);
//   outputPath.assign( finalPath );

//   return 0;
// #elif __linux__ || __unix__
//   char exePath[ 2048 ];
//   ssize_t count = ::readlink( "/proc/self/exe", exePath, sizeof(exePath)-1 );

//   if ( count > 0 )
//   {
//     char *dir;
//     exePath[count] = 0;
//     //printf("EXE Path: '%s' \n", exePath );

//     dir = ::dirname( exePath );

//     if ( dir )
//     {
//       //printf("DIR Path: '%s' \n", dir );
//       outputPath.assign( dir );
//       return 0;
//     }
//   }
// #elif    __APPLE__
#if __APPLE__
  char exePath[2048];
  uint32_t bufSize = sizeof(exePath);
  int result = _NSGetExecutablePath(exePath, &bufSize);

  if (result == 0)
  {
    char *dir;
    exePath[sizeof(exePath) - 1] = 0;
    // printf("EXE Path: '%s' \n", exePath );

    dir = ::dirname(exePath);

    if (dir)
    {
      // printf("DIR Path: '%s' \n", dir );
      outputPath.assign(dir);
      return 0;
    }
  }
#endif
  return -1;
}

static int getResourcesPath(std::string &outputPath)
{
  outputPath.clear();
  if (getExecutablePath(outputPath) == -1)
  {
    return -1;
  }
  outputPath += "/../Resources/";
  return 0;
}

// const char *getMacOsFilePath(const char *filename)
// {

//   // Get a reference to the main bundle
//   CFBundleRef mainBundle = CFBundleGetMainBundle();

//   // Get a reference to the file's URL
//   CFStringRef filenameHandle = CFStringRef("INLretro.ini");

//   CFStringRef file_name = CFStringRef("INLretro");
//   CFStringRef file_ext = CFStringRef("ini");

//   APP_LOG(filename);

//   // Get a reference to the file's URL
//   // CFURLRef fileURL = CFBundleCopyResourceURL(mainBundle, file_name, file_ext, NULL); // CFSTR("toto"), CFSTR("txt"), NULL);
//   CFURLRef fileURL = CFBundleCopyResourceURL(mainBundle, CFStringRef("INLretro.ini"), NULL, NULL);

//   // Convert the URL reference into a string reference
//   CFStringRef filePath = CFURLCopyFileSystemPath(fileURL, kCFURLPOSIXPathStyle);

//   // Get the system encoding method
//   CFStringEncoding encodingMethod = CFStringGetSystemEncoding();

//   // Convert the string reference into a C string
//   const char *path = CFStringGetCStringPtr(filePath, encodingMethod);

//   // CFURLRef appUrlRef;

//   // appUrlRef = CFBundleCopyResourceURL(CFBundleGetMainBundle(), CFSTR("AFE-MP-512"), NULL, NULL);
//   // CFStringRef filePathRef = CFURLCopyPath(appUrlRef);

//   // qDebug() << filePathRef;

//   // // Release references
//   CFRelease(filePath);
//   CFRelease(fileURL);

//   return path;
// }
#endif
#endif
