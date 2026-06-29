// Update 11

#include <Arrays\Array.mqh>
#include <Arrays\ArrayObj.mqh>




class JasonStruct {
    // Members for each data type
    int int_v;
    double dbl_v;
    bool bool_v;
    string str_v;

    // Members for JSON objects and arrays
    string children[];
    string keys[];
    int type;  // 0 for primitive types, 1 for object, 2 for array

    // Constructor
    JasonStruct() {
        // Initialize members
    }

    // Serialize method
    string Serialize() {
        // Loop through members and add them to JSON
        return "";
    }

    // Deserialize method
    void Deserialize(string json) {
        // Parse JSON and store values in members
    }

    // Methods for adding, removing, and accessing elements
void Add(string key, string value) {
    // Verificar se a chave já existe. Se sim, atualizar o valor existente.
    for (int i = 0; i < ArraySize(keys); i++) {
        if (keys[i] == key) {
            children[i] = value;
            return;
        }
    }

    // Se a chave não foi encontrada, adicione a nova chave e valor aos arrays.
    int newSize = ArraySize(keys) + 1;
    ArrayResize(keys, newSize);
    ArrayResize(children, newSize);
    keys[newSize - 1] = key;
    children[newSize - 1] = value;
}
    void Remove(string key) {
        // Remove a key-value pair
    }
    
    public:
    int Count(){
        return ArraySize(keys);
    }

    //JasonStruct Get(string key) {
    //    return JasonStruct;
    //    // Get a value by key
    //}
};

class OrderJason
{
private:
   CArrayObj<string, JasonStruct*> order_jasons;  // Array of KeyValuePair objects
   
public:
    ~OrderJason()  // Destructor
    {
        // Delete all JasonStruct objects
        for(int i = 0; i < order_jasons.Total(); i++)
        {
            delete order_jasons.At(i);
        }
    }

    void AddOrder(string key, JasonStruct* order)
    {
        order_jasons.Add(key, order);
    }

    int Count()
    {
        return order_jasons.Total();
    }

    bool SaveOrder(string key, JasonStruct* order)    
    {
        int idx = order_jasons.Find(key);
        if(idx >= 0){
            delete order_jasons.At(idx);
            order_jasons.Update(idx, order);
            return true;
        }

        // if key was not found, add new key-value pair
        order_jasons.Add(key, order);
        return true;
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