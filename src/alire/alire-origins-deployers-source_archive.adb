with Ada.Directories;

with Alire.Errors;

with Alire.OS_Lib.Subprocess;
with Alire.VFS;

with GNATCOLL.VFS;

package body Alire.Origins.Deployers.Source_Archive is

   package Dirs renames Ada.Directories;

   ------------
   -- Deploy --
   ------------

   overriding
   function Deploy (This : Deployer; Folder : String) return Outcome is
      use GNATCOLL.VFS;
      Archive_Name : constant String := This.Base.Archive_Name;
      Archive_File : constant String := Dirs.Compose (Folder, Archive_Name);
      Exit_Code    :          Integer;
   begin
      Trace.Debug ("Creating folder: " & Folder);
      Create (+Folder).Make_Dir;

      Trace.Detail ("Downloading archive: " & This.Base.Archive_URL);
      Exit_Code := OS_Lib.Subprocess.Spawn
        ("wget", This.Base.Archive_URL & " -q -O " & Archive_File);
      if Exit_Code /= 0 then
         return Outcome_Failure ("wget call failed with code" & Exit_Code'Img);
      end if;

      Trace.Detail ("Extracting source archive...");
      Unpack (Src_File => Archive_File,
              Dst_Dir  => Folder,
              Move_Up  => True);

      return Outcome_Success;
   end Deploy;

   ------------------
   -- Compute_Hash --
   ------------------

   overriding
   function Compute_Hash (This   : Deployer;
                          Folder : String;
                          Kind   : Hashes.Kinds) return Hashes.Any_Digest is
      Archive_Name : constant String := This.Base.Archive_Name;
      Archive_File : constant String := Dirs.Compose (Folder, Archive_Name);
   begin
      return Hashes.Digest (Hashes.Hash_File (Kind, Archive_File));
   end Compute_Hash;

   ------------
   -- Unpack --
   ------------

   procedure Unpack (Src_File : String;
                     Dst_Dir  : String;
                     Move_Up  : Boolean)
   is

      -----------------------
      -- Check_And_Move_Up --
      -----------------------

      procedure Check_And_Move_Up is
         Contents : constant VFS.Virtual_File_Vector :=
                      VFS.Read_Dir
                        (VFS.New_Virtual_File (VFS.From_FS (Dst_Dir)));
         Success  : Boolean;
      begin
         if Natural (Contents.Length) /= 1 or else
           not Contents.First_Element.Is_Directory
         then
            raise Checked_Error with Errors.Set
              ("Unexpected contents where a single directory was expected: "
               & Dst_Dir);
         end if;

         Trace.Debug ("Unpacked crate root detected as: "
                      & Contents.First_Element.Display_Base_Dir_Name);

         --  Move everything up one level:

         for File of VFS.Read_Dir (Contents.First_Element) loop
            declare
               use type VFS.Virtual_File;
               New_Name : constant VFS.Virtual_File :=
                            Contents.First_Element.Get_Parent /
                              VFS.Simple_Name (File);
            begin
               GNATCOLL.VFS.Rename
                 (File      => File,
                  Full_Name => New_Name,
                  Success   => Success);

               if not Success then
                  raise Checked_Error with Errors.Set
                    ("Could not rename " & File.Display_Full_Name
                     & " to " & New_Name.Display_Full_Name);
               end if;
            end;
         end loop;

         --  Delete the folder, that must be empty:

         Contents.First_Element.Remove_Dir (Success => Success);
         if not Success then
            raise Checked_Error with Errors.Set
              ("Could not remove supposedly empty directory: "
               & Contents.First_Element.Display_Full_Name);
         end if;

      end Check_And_Move_Up;

      package Subprocess renames Alire.OS_Lib.Subprocess;
   begin
      case Archive_Format (Src_File) is
         when Tarball =>
            Subprocess.Checked_Spawn
              ("tar", "xf " & Src_File & " -C " & Dst_Dir);
         when Zip_Archive =>
            Subprocess.Checked_Spawn
              ("unzip", "-q " & Src_File & " -d " & Dst_Dir);
         when Unknown =>
            raise Checked_Error with Errors.Set
              ("Given packed archive has unknown format: " & Src_File);
      end case;

      if Move_Up then
         Check_And_Move_Up;
      end if;
   end Unpack;

end Alire.Origins.Deployers.Source_Archive;