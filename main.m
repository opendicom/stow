//
//  main.m
//  stow
//
//  Created by jacquesfauquex on 2014-09-01.
//  Copyright (c) 2016 opendicom.com All rights reserved.

/*
 Source code and binaries are subject to the terms of the Mozilla Public License, v. 2.0.
 If a copy of the MPL was not distributed with this file, You can obtain one at
 http://mozilla.org/MPL/2.0/
 
 Covered Software is provided under this License on an “as is” basis, without warranty of
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
 death or personal injury resulting from such party’s negligence to the extent applicable
 law prohibits such limitation. Some jurisdictions do not allow the exclusion or limitation
 of incidental or consequential damages, so this exclusion and limitation may not apply to
 You.
 */

#import <Foundation/Foundation.h>
#import "sys/xattr.h"

static NSFileManager *fileManager=nil;

BOOL moveSOPInstance(NSString *src, NSArray *fileNames, NSString *dst, NSString *aet, NSString *ip)
{
    NSError *err=nil;
    
    if([fileManager fileExistsAtPath:dst]) return FALSE;
    if(![fileManager createDirectoryAtPath:dst withIntermediateDirectories:YES attributes:nil error:nil])
    {
        NSLog(@"could not create folder: %@",dst);
        return false;
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
                                         dst,
                                         [NSString stringWithFormat:@"%@@%@",aet,ip]
                                         ]
     ];
    
    BOOL noFailure=true;
    for (NSString *fileName in fileNames)
    {
        if (![fileManager moveItemAtPath:[src stringByAppendingPathComponent:fileName] toPath:[dst stringByAppendingPathComponent:fileName]error:&err])
        {
            NSLog(@"%@", [err description]);
            noFailure=false;
        }
    }
    return noFailure;
}


int main(int argc, const char * argv[])
{

    @autoreleasepool {

        NSError *err=nil;
        fileManager=[NSFileManager defaultManager];
        
        unsigned short dashDash = 0x2D2D;
        NSData *dashDashData =[NSData dataWithBytes:&dashDash length:2];
        
        unsigned short crlf = 0x0A0D;
        NSData *crlfData =[NSData dataWithBytes:&crlf length:2];

        //we create a new boundary for each stow and check that the boundary doesn´t match any data within DICOM FILES

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
         [1] X,
         [2] "179.24.147.16",
         [3] "/Volumes/TM/wfmFIR/DICOM/1.2.840.113619.2.81.290.27016.43807.20161109.210126",
         [4] "http://192.168.0.7:8080/dcm4chee-arc/aets/%@/rs/studies"
         */
        NSArray *args=[[NSProcessInfo processInfo] arguments];
        if ([args count]!=5) NSLog(@"ERROR stow args received: %@",[args description]);
        else
        {
            NSRange timestampSeparator=[args[3] rangeOfString:@"#"];
            NSString *StudyInstanceUID;
            if (timestampSeparator.length)StudyInstanceUID=[args[3] substringToIndex:timestampSeparator.location];
            else StudyInstanceUID=args[3];
            NSString *pacsURI=[NSString stringWithFormat:args[4],args[1]];

#pragma mark loop SOPInstanceUID
            NSArray *SOPInstanceUIDs=[fileManager contentsOfDirectoryAtPath:args[3] error:&err];
            NSUInteger SOPInstanceCount=[SOPInstanceUIDs count];
            NSMutableData *body = [NSMutableData data];
            NSMutableArray *packaged=[NSMutableArray array];
            for (NSUInteger i=0; i<SOPInstanceCount; i++)
            {

                if ([SOPInstanceUIDs[i] hasPrefix:@"."]) continue;

                [body appendData:cdbcData];
                [body appendData:ctadData];
                [body appendData:[NSData dataWithContentsOfFile:[args[3] stringByAppendingPathComponent:SOPInstanceUIDs[i]]]];
                [packaged addObject:SOPInstanceUIDs[i]];
#pragma mark send stow
                if (([body length] > 40000000) || (i==SOPInstanceCount-1))
                {
                    //finalize body
                    [body appendData:cdbdcData];
                    //create request
                    NSMutableURLRequest *request=
                    [NSMutableURLRequest requestWithURL:
                     [NSURL URLWithString:
                      [NSString stringWithFormat:@"%@/%@",
                       pacsURI,
                       [StudyInstanceUID lastPathComponent]]]];
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
                        
                        NSString *dest=[[[[[
                                            [StudyInstanceUID stringByDeletingLastPathComponent]
                                            stringByDeletingLastPathComponent]
                                           stringByAppendingPathComponent:@"ERROR"]
                                          stringByAppendingPathComponent:[StudyInstanceUID lastPathComponent]]
                                         stringByAppendingString:@"#"]
                                        stringByAppendingString:[[NSDate date]descriptionWithCalendarFormat:@"%Y%m%d%H%M%S" timeZone:nil locale:nil]];
                        if (moveSOPInstance(args[3], packaged, dest, args[1], args[2])) NSLog(@"response status code:%ld error:%@\r\nmoved to: %@",(long)[response statusCode],[err description],dest);
                        else NSLog(@"response status code:%ld error:%@\r\ncould not be moved to: %@\r\nList of sent files:\r\n%@",(long)[response statusCode],[err description],dest,[packaged description]);
                    }
                    else
                    {
                        //NSLog(@"%@",[[NSString alloc]initWithData:responseData encoding:NSUTF8StringEncoding]);
                        NSString *dest=[[[[[
                         [StudyInstanceUID stringByDeletingLastPathComponent]
                          stringByDeletingLastPathComponent]
                           stringByAppendingPathComponent:@"STOWED"]
                            stringByAppendingPathComponent:[StudyInstanceUID lastPathComponent]]
                             stringByAppendingString:@"#"]
                              stringByAppendingString:[[NSDate date]descriptionWithCalendarFormat:@"%Y%m%d%H%M%S" timeZone:nil locale:nil]];
                        if (!moveSOPInstance(args[3], packaged, dest, args[1], args[2])) NSLog(@"could not move all sent files to %@\r\nList of sent files:\r\n%@",dest,[packaged description]);
                        NSString *qidoRequest=[NSString stringWithFormat:@"%@?StudyInstanceUID=%@",pacsURI,[StudyInstanceUID lastPathComponent]];
                        //NSLog(@"%@",qidoRequest);
                        NSData *qidoResponse=[NSData dataWithContentsOfURL:[NSURL URLWithString:qidoRequest]];
                        if (!qidoResponse) NSLog(@"could not verify pacs reception of %@",dest);
                        else
                        {
                            NSDictionary *d=[NSJSONSerialization JSONObjectWithData:qidoResponse options:0 error:&err][0];

                            NSLog(@"%@ (%@,%@,%@)",dest,((d[@"00201206"])[@"Value"])[0],((d[@"00080061"])[@"Value"])[0],((d[@"00201208"])[@"Value"])[0]);
                        }
                    }
                    [body setData:[NSData data]];
                    [packaged removeAllObjects];
                }
            }
            if (![[fileManager contentsOfDirectoryAtPath:args[3] error:&err]count]) [fileManager removeItemAtPath:args[3] error:&err];
        }
    }
    return 0;
}

