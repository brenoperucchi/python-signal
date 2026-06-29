// Update 09
#include <Generic/HashMap.mqh>

class JasonStruct
{
public:
    long type;
    long ticket_master;
    long ticket_slave;
    long ticket_deal;
    long trace_id;
    long slave_id;
    long magic_number;
    long transaction_id;
    long timezone;
    double price_open;
    double volume;
    double stop_loss;
    double take_profit;
    double profit;
    double mae;
    double mfe;
    string state;
    string state_meta;
    string symbol;
    string time_gmt;
    string time_trader;
    long seconds_ago;
    string comment;
    string open_at;
    bool isValid;

    JasonStruct() 
    {
        isValid = false;  // Initialize isValid to false
    }
};

class OrderJason
{
private:
    CHashMap<string, JasonStruct*> order_jasons;  // HashMap of OrderStruct pointers

public:
    ~OrderJason()  // Destructor
    {
        // Delete all OrderStruct objects
        string keys[];
        JasonStruct* values[];
        order_jasons.CopyTo(keys, values);
        for(int i = 0; i < order_jasons.Count(); i++)
        {
            delete values[i];
        }
    }

    void AddOrder(string key, JasonStruct* order)
    {
        order_jasons.Add(key, order);
    }
    
    int Count(){
        return order_jasons.Count();
    }
    
    bool SaveOrder(string key, JasonStruct* order)    
    {
        JasonStruct* orderFind;
        order_jasons.TryGetValue(key, orderFind);
        if(orderFind.isValid){
          if(order_jasons.Remove(key))
            order_jasons.Add(key, order);
            return true;
        }
               
        return false;
    }    
    
string OrderJason::Serialize()
{
    // Arrays to hold the keys and values from the HashMap
    string keys[];
    JasonStruct* values[];

    // Copy the keys and values from the HashMap
    order_jasons.CopyTo(keys, values);

    // Start the JSON object
    string json = "{";

    // Iterate over the keys and values
    for(int i = 0; i < ArraySize(keys); i++)
    {
        // Get the current key and value
        string key = keys[i];
        JasonStruct* order = values[i];

        // Add the order to the JSON object
        json += "\"" + key + "\": " + OrderStructToJson(order);

        // If it is not the last element, append a comma
        if(i < ArraySize(keys) - 1)
        {
            json += ",";
        }
    }

    // Close the JSON object
    json += "}";

    // Return the JSON object
    return json;
}

string OrderJason::OrderStructToJson(JasonStruct* order)
{
    // Create an array of field names
    string fields[] = {"type", "ticket_master", "ticket_slave", "ticket_deal", "trace_id", "slave_id", "magic_number", "transaction_id", "timezone", "price_open", "volume", "stop_loss", "take_profit", "profit", "mae", "mfe", "state", "state_meta", "symbol", "time_gmt", "time_trader", "seconds_ago", "comment", "open_at", "isValid"};
    
    // Start the JSON object
    string json = "{";
    
    // Iterate over the fields
    for(int i = 0; i < ArraySize(fields); i++)
    {
        // Add the field name to the JSON
        json += "\"" + fields[i] + "\": ";
        
        // Add the field value to the JSON
        if(fields[i] == "type") json += IntegerToString(order.type);
        else if(fields[i] == "ticket_master") json += IntegerToString(order.ticket_master);
        // (repeat for each field)
        
        // If it is not the last field, add a comma
        if(i < ArraySize(fields) - 1) json += ",";
    }
    
    // Close the JSON object
    json += "}";
    
    // Return the JSON string
    return json;
}





    JasonStruct* OrderJason::FindOrderByTicketMaster(long ticketid)
    {
        // Convert ticketid to string, because in our implementation keys are strings
        string ticketidStr = IntegerToString(ticketid);
    
        // Check if an order with this ticket master exists in the map
        if (order_jasons.ContainsKey(ticketidStr))
        {
          JasonStruct* order;
          order_jasons.TryGetValue(ticketidStr, order);
          if(IntegerToString(order.ticket_master) == ticketidStr){
           
            order.isValid = true;
            return order;  // Return a pointer to the found order
          }
        }
        return NULL;  // Return NULL if no order was found
    }

};
