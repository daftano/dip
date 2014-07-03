/////////////////////////////////////////////////////
// IPdetect.java
//
// This applet connects back to the server from
// which it came and retrieves the IP address at
// its end of the connection. This address and any
// error message is then available to JavaScript
// code using the getLocal and getMsg class methods,
// respectively.
//
// If there is any error, the address is set to
// "javaerror".
//
// See COPYING for licensing information.
//
/////////////////////////////////////////////////////

import java.applet.*;
import java.net.*;

public class IPdetect extends Applet {

  // IP address 
  private String localaddress;
  public String getLocal() {
    return localaddress;
  }

  // error message
  private String errormsg;
  public String getMsg() {
    return errormsg;
  }

  // constructor
  public IPdetect() {
  }

  // initialization
  public void init() {
    try {
      // get host and port to connect
      URL url = getCodeBase();
      String host = url.getHost();
      int    port = url.getPort();
      if (port == -1) port = 80;

      // do the connect
      Socket sck = new Socket(host, port);

      // get address at our end
      localaddress = sck.getLocalAddress().getHostAddress();

      // close the connection
      sck.close();

      // no error message
      errormsg = "";
    }
    catch(Exception e) {
      // indicate an error occured
      localaddress = "javaerror";

      // provide error message
      errormsg = e.getMessage();
    }
  }
}

