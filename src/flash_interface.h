#ifndef _flash_interface_h_
#define _flash_interface_h_

int flashOpen(void);

int flash_cmd_init(void);
/**
 * Prepare to write a page of a new upgrade image.
 * The first word of data should be set to 0 if it is the first page,
 * 1 for all other pages and 2 to terminate the write (no further data is sent).
 */
int flash_cmd_write_page(unsigned char []);
/**
 * Provide upgrade image data. flash_cmd_write_page() must be called previously.
 * Once a page of data has been provided it is written to the device.
 */
int flash_cmd_write_page_data(unsigned char []);
/* Reads a page of the selected flash image.
 * Parameters:
 *  *data: a ptr to a memory buffer to put the image data in.
 *  init: If 1 only initialize strating read and return a 1 if a problem and a 0 if no problem. If 0 then return error and data in buffer
 *
 *  Returns:
 *  1 - Error
 *  0 - No Error
 */
int flash_cmd_read_page(unsigned char [], int);

int flash_cmd_erase_all(void);
int flash_cmd_reboot(void);

int flash_cmd_select_image(int);
int flash_cmd_print_select_image_info(void);

int flash_cmd_image_size(void);

#endif /*_flash_interface_h_*/
