//
//  storestow.mm
//  storestow
//
//  Created by jacquesfauquex on 2014-09-01.
//  Copyright (c) 2016 opendicom.com All rights reserved.

/*
 Source code and binaries are subject to the terms of the Mozilla Public License, v. 2.0.
 If a copy of the MPL was not distributed with this file, You can obtain one at
 http://mozilla.org/MPL/2.0/
 
 Covered Software is provided under this License on an Òas isÓ basis, without warranty of
 any kind, either expressed, implied, or statutory, including, without limitation,
 warranties that the Covered Software is free of defects, merchantable, fit for a particular
 purpose or non-infringing. The entire risk as to the quality and performance of the Covered
 Software is with You. Should any Covered Software prove defective in any respect, You (not
 any Contributor) assume the cost of any necessary servicing, repair, or correction. This
 disclaimer of warranty constitutes an essential part of this License. No use of any Covered
 Software is authorized under this License except under this disclaimer.
 
 Under no circumstances and under no legal theory, whether tort (including negligence),
 contract, or otherwise, shall any Contributor, or anyone who distributes Covered Software
 as permitted above, be liable to You for any direct, indirect, special, incidental, or
 consequential damages of any character including, without limitation, damages for lost
 profits, loss of goodwill, work stoppage, computer failure or malfunction, or any and all
 other commercial damages or losses, even if such party shall have been informed of the
 possibility of such damages. This limitation of liability shall not apply to liability for
 death or personal injury resulting from such partyÕs negligence to the extent applicable
 law prohibits such limitation. Some jurisdictions do not allow the exclusion or limitation
 of incidental or consequential damages, so this exclusion and limitation may not apply to
 You.
 */
#include "J2KR(noCodec).h"
#import "sys/xattr.h"

static NSError *err=nil;
int main(int argc, const char * argv[])
{
    @autoreleasepool {
        unsigned short dashDash = 0x2D2D;
        NSData *dashDashData =[NSData dataWithBytes:&dashDash length:2];
        
        unsigned short crlf = 0x0A0D;
        NSData *crlfData =[NSData dataWithBytes:&crlf length:2];
        
        //we create a new boundary for each stow and check that the boundary doesn«t match any data within DICOM FILES
        
        //cdbc:     \r\n--%@\r\n
        NSString *boundaryString=[[NSUUID UUID]UUIDString];
        NSData *boundaryData=[boundaryString dataUsingEncoding:NSASCIIStringEncoding];
        NSMutableData *mutableCdbc=[NSMutableData dataWithData:crlfData];
        [mutableCdbc appendData:dashDashData];
        [mutableCdbc appendData:boundaryData];
        [mutableCdbc appendData:crlfData];
        
        //cdbdc:    \r\n--%@--\r\n
        NSData *cdbcData=[NSData dataWithData:mutableCdbc];
        NSMutableData *mutableCdbdc=[NSMutableData dataWithData:crlfData];
        [mutableCdbdc appendData:dashDashData];
        [mutableCdbdc appendData:boundaryData];
        [mutableCdbdc appendData:dashDashData];
        [mutableCdbdc appendData:crlfData];
        NSData *cdbdcData=[NSData dataWithData:mutableCdbdc];
        
        //ctad: Content-Type:application/dicom
        NSData *ctadData=[@"Content-Type:application/dicom\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding];
        
        
        
        
        NSLog(@"%@",[[[NSProcessInfo processInfo] arguments]description]);
        
#pragma mark args
        /*
         [0] "/Users/Shared/stow/stow",
         [1] DCM4CHEE,
         [2] "179.24.147.16",
         [3] "/Volumes/TM/wfmFIR/DICOM/1.2.840.113619.2.81.290.27016.43807.20161109.210126",
         [4] "http://192.168.0.7:8080/dcm4chee-arc/aets/%@/rs/studies"
         [5] [institutionMapping.plist]
         */
        NSArray *args=[[NSProcessInfo processInfo] arguments];
        if (([args count]!=5) && ([args count]!=6)) NSLog(@"ERROR storestow args number");
        else
        {
            NSDictionary *institutionMapping=nil;
            if (args[5]) institutionMapping=[NSDictionary dictionaryWithContentsOfFile:args[5]];


            NSString *StudyInstanceUID=[args[3] lastPathComponent];
            NSString *pacsURIString=[NSString stringWithFormat:args[4],args[1]];
            NSURL *pacsURI=[NSURL URLWithString:[NSString stringWithFormat:@"%@/%@",pacsURIString,StudyInstanceUID]];
            NSString *qidoRequest=[NSString stringWithFormat:@"%@?StudyInstanceUID=%@",pacsURIString,StudyInstanceUID];

            
#pragma mark loop SOPInstanceUID
            NSArray *SOPInstanceUIDs=[[NSFileManager defaultManager] contentsOfDirectoryAtPath:args[3] error:&err];
            NSUInteger SOPInstanceCount=[SOPInstanceUIDs count];
            NSMutableData *body = [NSMutableData data];
            NSMutableArray *packaged=[NSMutableArray array];
            
            DJEncoderRegistration::registerCodecs(
                                                  ECC_lossyRGB,
                                                  EUC_never,
                                                  OFFalse,
                                                  OFFalse,
                                                  0,
                                                  0,
                                                  0,
                                                  OFTrue,
                                                  ESS_444,
                                                  OFFalse,
                                                  OFFalse,
                                                  0,
                                                  0,
                                                  0.0,
                                                  0.0,
                                                  0,
                                                  0,
                                                  0,
                                                  0,
                                                  OFTrue,
                                                  OFTrue,
                                                  OFFalse,
                                                  OFFalse,
                                                  OFTrue);

            //com.apple.metadata:_kMDItemUserTags
            //http://nshipster.com/extended-file-attributes/
            //http://apple.stackexchange.com/questions/110662/possible-to-tag-a-folder-via-terminal
            const char *name = "com.apple.metadata:_kMDItemUserTags";
            const char *red = [@"(\"not stowed\n6\")" UTF8String];
            const char *green = [@"(\"stowed\n2\")" UTF8String];
            BOOL studyStowed=true;

            for (NSUInteger i=0; i<SOPInstanceCount; i++)
            {
                
                if ([SOPInstanceUIDs[i] hasPrefix:@"."]) continue;
                
                [body appendData:cdbcData];
                [body appendData:ctadData];
                
                NSString *filePath=[args[3] stringByAppendingPathComponent:SOPInstanceUIDs[i]];
                
                DcmFileFormat fileformat;
                OFCondition cond = fileformat.loadFile( [filePath UTF8String]);
                DcmDataset *dataset = fileformat.getDataset();
                DcmXfer original_xfer(dataset->getOriginalXfer());
                BOOL mayJ2KR=false;
                if (!original_xfer.isEncapsulated())
                {
                    DJ_RPLossy JP2KParamsLossLess(0 );//DCMLosslessQuality
                    DcmRepresentationParameter *params = &JP2KParamsLossLess;
                    DcmXfer oxferSyn( EXS_JPEG2000LosslessOnly);
                    dataset->chooseRepresentation(EXS_JPEG2000LosslessOnly, params);
                    if (dataset->canWriteXfer(EXS_JPEG2000LosslessOnly)) mayJ2KR=true;
                    else NSLog(@"cannot J2KR: %@)",filePath);
                }
                fileformat.loadAllDataIntoMemory();

#pragma mark metadata adjustments for all files

                // 00081060=-^-^- NameofPhysiciansReadingStudy
                delete dataset->remove( DcmTagKey( 0x0008, 0x1060));
                dataset->putAndInsertString( DcmTagKey( 0x0008, 0x1060),[@"-^-^-" cStringUsingEncoding:NSASCIIStringEncoding] );

                // 00200010=29991231235959
                delete dataset->remove( DcmTagKey( 0x0020, 0x0010));
                dataset->putAndInsertString( DcmTagKey( 0x0020, 0x0010),[@"29991231235959" cStringUsingEncoding:NSASCIIStringEncoding] );

                // 00080090=-^-^-^-
                delete dataset->remove( DcmTagKey( 0x0008, 0x0090));
                dataset->putAndInsertString( DcmTagKey( 0x0008, 0x0090),[@"-^-^-^-" cStringUsingEncoding:NSASCIIStringEncoding] );
                
                //remove SQ reqService
                delete dataset->remove( DcmTagKey( 0x0032, 0x1034));
                
                // "GEIIS" The problematic private group, containing a *always* JPEG compressed PixelData
                delete dataset->remove( DcmTagKey( 0x0009, 0x1110));

#pragma mark institutionName adjustments
                if (institutionMapping)
                {
                    
                    // 00080080=institutionName
                    NSString *institutionName=institutionMapping[args[1]];
                    if (!institutionName) institutionName=institutionMapping[args[2]];
                    if (institutionName)
                    {
                        delete dataset->remove( DcmTagKey( 0x0008, 0x0080));
                        dataset->putAndInsertString( DcmTagKey( 0x0008, 0x0080),[institutionName cStringUsingEncoding:NSASCIIStringEncoding] );
                    }
                }
                
                
#pragma mark compress and add to stream (revisar bien a que corresponde toda esta sintaxis!!!)
                NSString *J2KR=[filePath stringByAppendingPathExtension:@"j2kr"];
                NSString *ELE=[filePath stringByAppendingPathExtension:@"ele"];
                if (
                       mayJ2KR
                    && (
                        (fileformat.saveFile(
                         [J2KR UTF8String],
                         EXS_JPEG2000LosslessOnly
                         )
                        ).good()
                       )
                    )
                {
                    [body appendData:[NSData dataWithContentsOfFile:J2KR]];
                    [packaged addObject:J2KR];
                }
                else if (
                         (fileformat.saveFile(
                                              [ELE UTF8String],
                                              EXS_LittleEndianExplicit
                                              )
                          ).good()
                         )
                {
                    [body appendData:[NSData dataWithContentsOfFile:ELE]];
                    [packaged addObject:ELE];
                }
                else
                {
                    [body appendData:[NSData dataWithContentsOfFile:filePath]];
                    [packaged addObject:SOPInstanceUIDs[i]];
                }

                
#pragma mark send stow
                if (([body length] > 10000000) || (i==SOPInstanceCount-1))
                {
                    NSLog(@"sending: %d bytes",[body length]);
                    //finalize body
                    [body appendData:cdbdcData];
                    //create request
                    NSMutableURLRequest *request=
                    [NSMutableURLRequest requestWithURL:pacsURI];
                    [request setHTTPMethod:@"POST"];
                    [request setTimeoutInterval:300];
                    NSString *contentType = [NSString stringWithFormat:@"multipart/related;type=application/dicom;boundary=%@", boundaryString];
                    [request addValue:contentType forHTTPHeaderField:@"Content-Type"];
                    [request setHTTPBody:body];
                    
                    //send stow
                    NSHTTPURLResponse *response;
                    NSData *responseData=[NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&err];
                    if (  !responseData
                        ||!(
                            ([response statusCode]==200)
                            ||([response statusCode]==500)
                            )
                        )
                    {
                        NSLog(@"%@",[response description]);
                        //NSLog(@"%@",[[NSString alloc]initWithData:responseData encoding:NSUTF8StringEncoding]);
                        studyStowed=false;
                        /*
                         Failure
                         =======
                         400 - Bad Request (bad syntax)
                         401 - Unauthorized
                         403 - Forbidden (insufficient priviledges)
                         409 - Conflict (formed correctly - system unable to store due to a conclict in the request
                         (e.g., unsupported SOP Class or StudyInstance UID mismatch)
                         additional information can be found in teh xml response body
                         415 - unsopported media type (e.g. not supporting JSON)
                         500 (instance already exists in db - delete file)
                         503 - Busy (out of resource)
                         
                         Warning
                         =======
                         202 - Accepted (stored some - not all)
                         additional information can be found in teh xml response body
                         
                         Success
                         =======
                         200 - OK (successfully stored all the instances)
                         
                         */
                        
                        for (NSString *fp in packaged)
                        {
                            const char *c = [fp fileSystemRepresentation];
                            if (setxattr(c, name, red, strlen(red), 0, 0)==-1)NSLog(@"not stowed and not red-colored %@",fp);
                            if (![[fp pathExtension]isEqualToString:@"dcm"])
                            {
                                NSString *fpd=[fp stringByDeletingPathExtension];
                                const char *d = [fpd fileSystemRepresentation];
                                if (setxattr(d, name, red, strlen(red), 0, 0)==-1)NSLog(@"not stowed and not red-colored %@",fpd);
                            }
                            
                        }
                    }
                    else
                    {
                        for (NSString *fp in packaged)
                        {
                            const char *c = [fp fileSystemRepresentation];
                            if (setxattr(c, name, green, strlen(green), 0, 0)==-1)NSLog(@"stowed but not green-colored %@",fp);
                            if (![[fp pathExtension]isEqualToString:@"dcm"])
                            {
                                NSString *fpd=[fp stringByDeletingPathExtension];
                                const char *d = [fpd fileSystemRepresentation];
                                if (setxattr(d, name, green, strlen(green), 0, 0)==-1)NSLog(@"stowed but not gren-colored %@",fpd);
                            }
                            
                        }
                        
                        NSData *qidoResponse=[NSData dataWithContentsOfURL:[NSURL URLWithString:qidoRequest]];
                        if (!qidoResponse) NSLog(@"status:%d  -  could not verify pacs reception",[response statusCode] );
                        else
                        {
                            NSDictionary *d=[NSJSONSerialization JSONObjectWithData:qidoResponse options:0 error:&err][0];
                            
                            //NSLog(@"%@",[args[3] lastPathComponent]);
                            NSLog(@"status:%d\r\n%@ - %@/%@",
                                  [response statusCode],
                                  ((d[@"00080061"])[@"Value"])[0],
                                  ((d[@"00201206"])[@"Value"])[0],
                                  ((d[@"00201208"])[@"Value"])[0]
                                  );
                        }
                    }
                    [body setData:[NSData data]];
                    [packaged removeAllObjects];
                }
            }
            const char *f = [args[3] fileSystemRepresentation];
            if (studyStowed)
            {
                if(-1==setxattr(f, name, green, strlen(green), 0, 0))NSLog(@"stowed but not gren-colored %@",args[3]);
            }
            else
            {
                if (-1==setxattr(f, name, red, strlen(red), 0, 0))NSLog(@"not stowed and not gren-colored %@",args[3]);
            }
    
            //http://superuser.com/questions/82106/where-does-spotlight-store-its-metadata-index/256311#256311
            //osascript -e 'on run {f, c}' -e 'tell app "Finder" to set comment of (POSIX file f as alias) to c' -e end /Users/jacquesfauquex/a hola
            [NSTask launchedTaskWithLaunchPath:@"/usr/bin/osascript"
                                     arguments:@[@"-e",
                                                 @"on run {f, c}",
                                                 @"-e",
                                                 @"tell app \"Finder\" to set comment of (POSIX file f as alias) to c",
                                                 @"-e",
                                                 @"end",
                                                 args[3],
                                                 [NSString stringWithFormat:@"%@@%@",args[1],args[2]]
                                                 ]
             ];

        }
    }
    return 0;
}

