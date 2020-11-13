% Lucia Cantú-Miller A01194199
% Paola Villarreal A00821971
% Alan Zavala A01338448

% COMO USARLO
% 1. Cambiar el nombre de tu maquina en la linea 16
% 2. Crear un nodo en una terminal => erl -sname tienda
% 3. Compilarlo con c(t6).
% 4. Registrar el proceso => t6:abre_tienda().

-module(t6).
-m([lists,math,io]).
-export([abre_tienda/0, cierra_tienda/0, tienda/0, suscribir_socio/1, elimina_socio/1, lista_socios/0, registra_producto/2, elimina_producto/1, modifica_producto/2, lista_existencias/0, producto/2]).

% nombre corto del servidor (nombre@máquina)
nodo(Nombre) -> list_to_atom(atom_to_list(Nombre)++"@DESKTOP-2JRT0KR"). %CAMBIAR A NOMBRE DE TU MAQUINA

% CÓDIGO PARA LA TIENDA

tienda() ->
    process_flag(trap_exit, true),
    tienda([], []).
tienda(Lista_Socios, Lista_Productos) ->
    receive
        {suscribir_socio, Nombre_Socio} ->
            case lists:member(Nombre_Socio, Lista_Socios) of
                false ->
                    io:format("socio ~s creado ~n", [Nombre_Socio]),    
                    tienda(Lista_Socios++[Nombre_Socio], Lista_Productos);
                true -> 
                    io:format("el socio ~s ya existe ~n", [Nombre_Socio]),
                    tienda(Lista_Socios, Lista_Productos)
            end;
        {elimina_socio, Nombre_Socio} ->
             case lists:member(Nombre_Socio, Lista_Socios) of
                false ->
                    io:format("socio ~s no existe~n", [Nombre_Socio]),    
                    tienda(Lista_Socios, Lista_Productos);
                true -> 
                    io:format("el socio ~s fue eliminado ~n", [Nombre_Socio]),
                    tienda(eliminar(Nombre_Socio, Lista_Socios), Lista_Productos)
            end;
        lista_socios ->
            io:format("Socios registrados = ~s~n", [Lista_Socios]),
            tienda(Lista_Socios, Lista_Productos);
        {registra_producto, Nombre_Producto, Cantidad} ->
            case lists:keyfind(Nombre_Producto, 1, Lista_Productos) of
                false ->
                    Pid = spawn(t6, producto, [Nombre_Producto, Cantidad]),
                    io:format("producto ~s creado ~n", [Nombre_Producto]),
                    tienda(Lista_Socios, Lista_Productos++[{Nombre_Producto, Pid}]);
                {Nombre_Producto, _} ->
                    io:format("producto ~s ya existe ~n", [Nombre_Producto]),
                    tienda(Lista_Socios, Lista_Productos)
            end;
        {De, {elimina_producto, Nombre_Producto}} ->
            case busca_productos(Nombre_Producto, Lista_Productos) of
                inexistente ->
                    De ! inexistente;
                Epid ->
                    Epid ! {eliminar, Nombre_Producto},
                    De ! eliminado
            end,
            tienda(Lista_Socios, Lista_Productos);
        {De, {modifica_producto, Nombre_Producto, Cantidad}} ->
            case busca_productos(Nombre_Producto, Lista_Productos) of
                inexistente ->
                    De ! inexistente;
                Epid ->
                    Epid ! {modificado, Nombre_Producto, Cantidad},
                    De ! modificado
            end,
            tienda(Lista_Socios, Lista_Productos);
        lista_existencias ->
            lists:map(fun({_, Epid}) -> 
		              Epid ! lista end, Lista_Productos);
        termina ->
            lists:map(fun({N, Epid}) -> 
		              Epid ! {termina, N} end, Lista_Productos)
    end.

% CÓDIGO PARA LOS PRODUCTOS

producto(N, C) ->
   receive
        {eliminar, Producto} ->
	        io:format("El producto ~s ha sido eliminado~n", [Producto]);
        {modificado, Producto, Cantidad} ->
            case C + Cantidad >= 0 of
                false ->
                    io:format("El producto ~s no pudo ser modificado debido a que la cantidad excede las existencias~n", [Producto]),
                    producto(N, C);
                true ->
                    io:format("El producto ~s ha sido modificado~n", [Producto]),
                    producto(N, C+Cantidad)
                end;
        lista ->
            io:format("~s ~w ~n", [N, C]),
            producto(N, C);
        {termina, Nombre} ->
            io:format("La venta de ~s ha terminado~n", [Nombre])
   end.

% FUNCIONES AUXILIARES

% busca un nombre dentro de la lista de productos
busca_productos(_, []) -> inexistente;
busca_productos(N, [{N, PID}|_]) -> PID; 
busca_productos(N, [_|Resto]) -> busca_productos(N, Resto).

% elimina de la lista el nombre recibido
eliminar(N, L) ->
    [Y || Y <- L, Y =/= N].

% FUNCIONES DE INTERFAZ DE USUARIO

% crea y registra el proceso de la tienda con el alias "tienda"
abre_tienda() ->
    register(tienda, spawn(t6, tienda, [])),
    'tienda abierta'.

% suscribe socios creando procesos en el nodo "socios"
suscribir_socio(Socio) ->
    {tienda, nodo(tienda)} ! {suscribir_socio, Socio},
    ok.

% elimina el socio correspondiente
elimina_socio(Socio) ->
    {tienda, nodo(tienda)} ! {elimina_socio, Socio},
    ok.

% lista todos los socios existentes
lista_socios() ->
    {tienda, nodo(tienda)} ! lista_socios,
    ok.

% registra productos creando procesos en el nodo "productos"
registra_producto(Producto, Cantidad) ->
    {tienda, nodo(tienda)} ! {registra_producto, Producto, Cantidad},
    ok.

% elimina productos deteniendo el proceso correspondiente, si existe, en el nodo "productos"
elimina_producto(Producto) -> 
    {tienda, nodo(tienda)} ! {self(), {elimina_producto, Producto}},
    receive 
        inexistente -> 
	        io:format("El producto ~s no existe~n", [Producto]);
	    eliminado ->
	        {Producto}
    end.

% modifica la cantidad de los productos si existe y si es posible
modifica_producto(Producto, Cantidad) -> 
    {tienda, nodo(tienda)} ! {self(), {modifica_producto, Producto, Cantidad}},
    receive 
        inexistente -> 
	        io:format("El producto ~s no existe~n", [Producto]);
        modificado ->
	        {Producto}
    end.

% lista todos los productos existentes con sus cantidades
lista_existencias() ->
    {tienda, nodo(tienda)} ! lista_existencias,
    ok.

% cierra la tienda, terminando todos los procesos de los productos
cierra_tienda() ->
    {tienda, nodo(tienda)} ! termina,
    ok.